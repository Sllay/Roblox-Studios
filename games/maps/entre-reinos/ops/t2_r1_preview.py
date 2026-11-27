"""Publish the approved T2-R1 preview to its existing staging Place."""

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
ROLLBACK_SHA = "98f81262ff93066c759b915253d557193e3efc9f"

require = scene_sync.require


def checked_target(plan, games, targets):
    require(plan.get("candidate") == CANDIDATE, "Unapproved preview candidate")
    target = deploy.resolve(games, targets, GAME, "main", "staging")
    for field, expected in (("universeId", V18_UNIVERSE), ("placeId", V18_PLACE)):
        require(plan.get(field) == target[field] == expected, f"Unauthorized preview {field}")
    require(target["fullPlaceBuildAuthoritative"], "Full Place replacement is disabled")
    production = targets[GAME]["environments"]["production"]
    require(production["universeId"] is None and production["placeIds"]["main"] is None,
            "Unexpected production mapping")
    require(plan.get("action") == "publish" and plan.get("confirmFullReplacement") is True,
            "Explicit staging replacement confirmation required")
    require(plan.get("expectedVersion") == 18, "This preview only replaces staging v18")
    baseline = scene_sync.read(scene_sync.state_path(target))
    require(baseline["loadedVersion"] == 18 and baseline["stateDigest"] == plan.get("expectedDigest"),
            "Review the current staging v18 Scene Sync baseline")
    return target


def check_identity(target, key):
    identity = place_provision.task(target, key, "identity")
    require(identity.get("verified") is True, "Staging identity unverified")
    require((identity["creatorType"], identity["creatorId"]) == OWNER, "Staging owner mismatch")
    require(identity["loadedVersion"] == 18, "Staging is no longer at v18")


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


def verify_scripts(expected, observed):
    hashes = {}
    for row in observed["records"].values():
        if row.get("class") in SCRIPT_CLASSES:
            path = scene_sync.canonical([row["service"], row["path"]])
            if path in expected:
                hashes[path] = row["properties"].get("sourceHash")
    require(hashes == expected, "Roblox script hashes differ from the checked build")


def publish(target, key, out, plan):
    artifact = target["file"]
    hashes = script_hashes(artifact)
    rollback_file = out / "entre-reinos-v18-rollback.rbxlx"
    rollback_scripts = script_hashes(rollback_file)
    subprocess.run([sys.executable, str(deploy.ROOT / "tools/script_quality.py")], check=True)

    check_identity(target, key)
    historical = scene_sync.capture(target, key, read_version=18)
    require(historical["loadedVersion"] == 18 and historical["stateDigest"] == plan["expectedDigest"],
            "Historical v18 rollback scene not verified")
    verify_scripts(rollback_scripts, historical)
    scene_sync.write(out / "baseline.json", historical)
    rollback = {
        "candidate": ROLLBACK_SHA, "revision": 18, "sceneDigest": historical["stateDigest"],
        "artifactSha256": hashlib.sha256(rollback_file.read_bytes()).hexdigest(),
        "scriptsVerified": len(rollback_scripts),
    }
    scene_sync.write(out / "rollback.json", rollback)
    print("PREVIEW_ROLLBACK", json.dumps(rollback), flush=True)

    # Official publisher compares the current scene against the recorded v18
    # baseline again immediately before sending the Assets API write.
    result = io.StringIO()
    try:
        with redirect_stdout(result):
            deploy.publish(target, key)
    finally:
        print(result.getvalue(), end="", flush=True)
    match = re.search(rf"^SUCCESS: Place {target['placeId']}, revision ([1-9][0-9]*)$",
                      result.getvalue(), re.MULTILINE)
    require(match and int(match[1]) > 18, "Roblox published revision unconfirmed")
    scene_sync.write(out / "publication.json", {
        "candidate": CANDIDATE, "universeId": target["universeId"], "placeId": target["placeId"],
        "revision": int(match[1]), "isPublished": True, "baselineDigest": historical["stateDigest"],
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
    verify_scripts(receipt["scriptHashes"], observed)
    require(observed["records"]["environment:workspace"]["StreamingEnabled"] is True,
            "Streaming disabled in published preview")
    proof = {k: receipt[k] for k in ("candidate", "universeId", "placeId", "revision", "artifactSha256")}
    proof.update(scriptsVerified=len(receipt["scriptHashes"]), sceneDigest=observed["stateDigest"],
                 playUrl=f"https://www.roblox.com/games/{target['placeId']}")
    scene_sync.write(out / "readback.json", proof)
    print("PREVIEW_READBACK", json.dumps(proof), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("phase", choices=["publish", "readback"])
    parser.add_argument("--plan", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=deploy.ROOT, text=True).strip()
    require(head == CANDIDATE, "Checkout must be the exact approved candidate")
    plan = scene_sync.read(args.plan)
    target = checked_target(plan, *deploy.load_all())
    key = os.environ.get("ROBLOX_OPEN_CLOUD_API_KEY")
    require(key, "Existing staging Open Cloud credential is unavailable")
    if args.phase == "publish":
        publish(target, key, args.output, plan)
    else:
        readback(target, key, args.output)


if __name__ == "__main__":
    try:
        main()
    except (deploy.WorkspaceError, OSError, ValueError, KeyError, subprocess.CalledProcessError) as exc:
        sys.exit(f"ERROR: {exc}")
