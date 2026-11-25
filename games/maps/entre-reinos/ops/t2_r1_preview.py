"""One-shot T2-R1 preview. Run only in the dedicated Actions workflow."""

from __future__ import annotations

import argparse
import base64
from collections import Counter
from contextlib import redirect_stdout
import hashlib
import io
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from xml.etree import ElementTree

import deploy
import place_provision
import scene_sync


GAME = "entre-reinos"
CANDIDATE = "f7d4ac685f2372d066cdf49a19b2b978f2454745"
V18_UNIVERSE = "10769712413"
V18_PLACE = "90623742498445"
# Verified with the official Place Provision inventory run 45681890920.
OWNER = ("User", "8136365379")
SCRIPT_CLASSES = {"Script", "LocalScript", "ModuleScript"}
DEFAULT_WORKSPACE = {("Camera", "Camera"), ("Baseplate", "Part"), ("Terrain", "Terrain"),
                     ("SpawnLocation", "SpawnLocation")}
DEFAULT_STARTER = {("StarterPlayerScripts", "StarterPlayerScripts"),
                   ("StarterCharacterScripts", "StarterCharacterScripts")}

require = scene_sync.require


def checked_target(plan, games, targets):
    require(plan.get("candidate") == CANDIDATE, "Unapproved preview candidate")
    require(plan.get("action") in {"inspect", "publish"}, "Unknown preview action")
    u = deploy.normalized_id(plan.get("universeId"), "preview Universe")
    p = deploy.normalized_id(plan.get("placeId"), "preview Place")
    require(u and p and u != V18_UNIVERSE and p != V18_PLACE, "Preview must use a new Universe and Place")
    for cfg in targets.values():
        for mapping in cfg["environments"].values():
            require(u != str(mapping["universeId"]), "Preview Universe aliases a registered destination")
            require(p not in map(str, mapping["placeIds"].values()), "Preview Place aliases a registered destination")
    staging = targets[GAME]["environments"]["staging"]
    require(str(staging["universeId"]) == V18_UNIVERSE and str(staging["placeIds"]["main"]) == V18_PLACE,
            "Canonical staging mapping changed")
    if plan["action"] == "publish":
        require(plan.get("confirmFullReplacement") is True, "Explicit full replacement confirmation required")
        require(type(plan.get("expectedVersion")) is int and plan["expectedVersion"] > 0,
                "Review the isolated Place version before publication")
        require(re.fullmatch(r"[a-f0-9]{64}", str(plan.get("expectedDigest", ""))) is not None,
                "Review the isolated Place digest before publication")
    # This mapping is in memory only. The v18 mapping and baseline stay in Git.
    staging.update(universeId=u, placeIds={"main": p})
    deploy.validate_global_targets(targets)
    target = deploy.resolve(games, targets, GAME, "main", "staging")
    require(target["fullPlaceBuildAuthoritative"], "Full Place replacement is disabled")
    return target


def check_default_scene(observed):
    require(observed["loadedVersion"] >= 1, "The isolated Place has no published baseline")
    roots = set()
    for row in observed["records"].values():
        if "service" not in row:
            require("solidVoxels" not in row or row["solidVoxels"] == row["waterVoxels"] == 0,
                    "Preview placeholder contains Terrain content")
            continue
        path = row["path"]
        root = (path[0]["name"], path[0]["class"])
        if row["service"] == "Workspace":
            require(root in DEFAULT_WORKSPACE and not row["managedId"], "Unexpected Workspace content")
            if len(path) == 1:
                roots.add(root)
            else:
                require(len(path) == 2 and row["class"] in {"Texture", "Decal"}
                        and root[0] in {"Baseplate", "SpawnLocation"}, "Unexpected object in blank Workspace")
        elif row["service"] == "StarterPlayer":
            require(root in DEFAULT_STARTER and not row["managedId"], "Unexpected StarterPlayer content")
            if len(path) > 1:
                require(root[0] == "StarterPlayerScripts" and path[1]["name"] == "PlayerModule",
                        "Unexpected authored client content")
        else:
            require((row["service"], row["class"]) in {
                ("Lighting", "Atmosphere"), ("Lighting", "Sky"), ("Lighting", "BloomEffect"),
                ("Lighting", "DepthOfFieldEffect"), ("Lighting", "SunRaysEffect"),
                ("SoundService", "SoundGroup"),
            } and len(path) == 1 and not row["managedId"], "Unexpected object in blank experience")
    require({("Terrain", "Terrain"), ("Baseplate", "Part")} <= roots, "Use the blank Baseplate template")


def check_identity(target, key):
    identity = place_provision.task(target, key, "inventory", templateEligible=False)
    require(identity.get("verified") is True, "Preview identity unverified")
    require((identity["creatorType"], identity["creatorId"]) == OWNER, "Preview owner differs from v18 owner")
    require([p["id"] for p in identity["places"]] == [target["placeId"]],
            "Preview must be the sole Place in its dedicated Universe")
    return identity["loadedVersion"]


def script_hashes(artifact):
    def visit(item, service, parent, hashes):
        siblings = Counter()
        for child in item.findall("Item"):
            props = child.find("Properties")
            name = props.find("./*[@name='Name']").text
            cls = child.attrib["class"]
            siblings[(name, cls)] += 1
            path = parent + [{"name": name, "class": cls, "ordinal": siblings[(name, cls)]}]
            if cls in SCRIPT_CLASSES:
                source = props.find("./*[@name='Source']").text or ""
                digest = base64.b64encode(hashlib.sha256(source.encode()).digest()).decode()
                hashes[scene_sync.canonical([service, path])] = digest
            visit(child, service, path, hashes)

    hashes = {}
    for service in ElementTree.parse(artifact).getroot().findall("Item"):
        visit(service, service.attrib["class"], [], hashes)
    require(bool(hashes), "No script hashes in the preview build")
    return hashes


def inspect(target, key, out, plan):
    version = check_identity(target, key)
    observed = scene_sync.capture(target, key)
    scene_sync.write(out / "baseline.json", observed)
    require(observed["loadedVersion"] == version, "Scene revision changed during inspection")
    check_default_scene(observed)
    print("PREVIEW_BASELINE", json.dumps({k: observed[k] for k in
          ("universeId", "placeId", "loadedVersion", "stateDigest", "total")}), flush=True)
    if plan["action"] == "publish":
        require(version == plan["expectedVersion"] and observed["stateDigest"] == plan["expectedDigest"],
                "Isolated Scene Sync baseline drifted since review")
    return observed


def publish(target, key, out, plan):
    artifact = target["file"]
    hashes = script_hashes(artifact)
    subprocess.run([sys.executable, str(deploy.ROOT / "tools/script_quality.py")], check=True)
    observed = inspect(target, key, out, plan)
    # Give the official pre-write guard the reviewed baseline in a disposable
    # checkout of the exact candidate. No canonical baseline is committed.
    path = scene_sync.state_path(target)
    original = path.read_bytes()
    result = io.StringIO()
    try:
        scene_sync.write(path, observed)
        with redirect_stdout(result):
            deploy.publish(target, key)
    finally:
        path.write_bytes(original)
        print(result.getvalue(), end="", flush=True)
    match = re.search(rf"^SUCCESS: Place {target['placeId']}, revision ([1-9][0-9]*)$",
                      result.getvalue(), re.MULTILINE)
    require(match and int(match[1]) > observed["loadedVersion"], "Roblox published revision unconfirmed")
    scene_sync.write(out / "publication.json", {
        "candidate": CANDIDATE, "universeId": target["universeId"], "placeId": target["placeId"],
        "revision": int(match[1]), "isPublished": True, "baselineDigest": observed["stateDigest"],
        "artifactSha256": hashlib.sha256(artifact.read_bytes()).hexdigest(),
        "scriptHashes": hashes,
    })


def readback(target, key, out):
    receipt = scene_sync.read(out / "publication.json")
    require(receipt["isPublished"] is True and receipt["candidate"] == CANDIDATE
            and receipt["universeId"] == target["universeId"] and receipt["placeId"] == target["placeId"],
            "Invalid publication receipt")
    observed = scene_sync.capture(target, key)
    scene_sync.write(out / "post-publish-inventory.json", observed)
    require(observed["loadedVersion"] == receipt["revision"], "Independent readback loaded a different revision")
    hashes = {}
    for row in observed["records"].values():
        if row.get("class") in SCRIPT_CLASSES:
            path = scene_sync.canonical([row["service"], row["path"]])
            if path in receipt["scriptHashes"]:
                hashes[path] = row["properties"].get("sourceHash")
    require(hashes == receipt["scriptHashes"], "Published script hashes differ from the candidate build")
    require(observed["records"]["environment:workspace"]["StreamingEnabled"] is True,
            "Streaming disabled in published preview")
    proof = {k: receipt[k] for k in ("candidate", "universeId", "placeId", "revision", "artifactSha256")}
    proof.update(scriptsVerified=len(hashes), sceneDigest=observed["stateDigest"],
                 playUrl=f"https://www.roblox.com/games/{target['placeId']}")
    scene_sync.write(out / "readback.json", proof)
    print("PREVIEW_READBACK", json.dumps(proof), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("phase", choices=["inspect", "publish", "readback"])
    parser.add_argument("--plan", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=deploy.ROOT, text=True).strip()
    require(head == CANDIDATE, "Checkout must be the exact approved candidate")
    plan = scene_sync.read(args.plan)
    target = checked_target(plan, *deploy.load_all())
    require(plan["action"] == args.phase or args.phase == "readback" and plan["action"] == "publish",
            "Workflow phase differs from the checked-in plan")
    key = os.environ.get("ROBLOX_T2_R1_PREVIEW_API_KEY")
    require(key, "Configure the scoped staging secret ROBLOX_T2_R1_PREVIEW_API_KEY")
    if args.phase == "inspect":
        inspect(target, key, args.output, plan)
    elif args.phase == "publish":
        publish(target, key, args.output, plan)
    else:
        readback(target, key, args.output)


if __name__ == "__main__":
    try:
        main()
    except (deploy.WorkspaceError, OSError, ValueError, KeyError, subprocess.CalledProcessError) as exc:
        sys.exit(f"ERROR: {exc}")
