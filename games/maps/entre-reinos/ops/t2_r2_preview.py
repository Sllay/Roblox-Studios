"""Publish the approved T2-R2 preview to its existing staging Place."""

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
CANDIDATE = "c905eca3437ecd124c6afac6cce0df21df31f8e1"
STAGING_UNIVERSE = "10769712413"
STAGING_PLACE = "90623742498445"
# Verified with the official Place Provision inventory run 45681890920.
OWNER = ("User", "8136365379")
SCRIPT_CLASSES = {"Script", "LocalScript", "ModuleScript"}
BASELINE_VERSION = 19
BASELINE_DIGEST = "4791eeead3928fe5187339b982f594a71987866b6ee263d06fe41b1453b0d482"
ROLLBACK_SHA = "f7d4ac685f2372d066cdf49a19b2b978f2454745"
ROLLBACK_BUILD_SHA = "1c18dfcebe528e3aa693db951148607cc417a5632c5ebc4e0418d3397466b885"

require = scene_sync.require


def checked_target(plan, games, targets):
    require(plan.get("candidate") == CANDIDATE, "Unapproved preview candidate")
    target = deploy.resolve(games, targets, GAME, "main", "staging")
    for field, expected in (("universeId", STAGING_UNIVERSE), ("placeId", STAGING_PLACE)):
        require(plan.get(field) == target[field] == expected, f"Unauthorized preview {field}")
    require(target["fullPlaceBuildAuthoritative"], "Full Place replacement is disabled")
    production = targets[GAME]["environments"]["production"]
    require(production["universeId"] is None and production["placeIds"]["main"] is None,
            "Unexpected production mapping")
    require(plan.get("action") == "publish" and plan.get("confirmFullReplacement") is True,
            "Explicit staging replacement confirmation required")
    require(plan.get("expectedVersion") == BASELINE_VERSION
            and plan.get("expectedDigest") == BASELINE_DIGEST,
            "This preview only replaces the reviewed staging v19 baseline")
    return target


def check_identity(target, key):
    identity = place_provision.task(target, key, "identity")
    require(identity.get("verified") is True, "Staging identity unverified")
    require((identity["creatorType"], identity["creatorId"]) == OWNER, "Staging owner mismatch")
    require(identity["loadedVersion"] == BASELINE_VERSION, "Staging is no longer at v19")


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


def publish(target, key, out):
    artifact = target["file"]
    hashes = script_hashes(artifact)
    rollback_file = out / "entre-reinos-v19-rollback.rbxlx"
    rollback_build = hashlib.sha256(rollback_file.read_bytes()).hexdigest()
    require(rollback_build == ROLLBACK_BUILD_SHA, "Rollback differs from the published v19 build")
    rollback_scripts = script_hashes(rollback_file)
    subprocess.run([sys.executable, str(deploy.ROOT / "tools/script_quality.py")], check=True)

    check_identity(target, key)
    historical = scene_sync.capture(target, key, read_version=BASELINE_VERSION)
    require(historical["loadedVersion"] == BASELINE_VERSION and historical["stateDigest"] == BASELINE_DIGEST,
            "Historical v19 rollback scene not verified")
    verify_scripts(rollback_scripts, historical)
    scene_sync.write(out / "baseline.json", historical)
    rollback = {
        "candidate": ROLLBACK_SHA, "revision": BASELINE_VERSION, "sceneDigest": historical["stateDigest"],
        "artifactSha256": rollback_build,
        "scriptsVerified": len(rollback_scripts),
    }
    scene_sync.write(out / "rollback.json", rollback)
    print("PREVIEW_ROLLBACK", json.dumps(rollback), flush=True)

    # The approved gameplay commit predates the v19 Scene Sync. Refresh the
    # disposable checkout's baseline so the official publisher can still
    # compare the current scene immediately before the Assets API write.
    path = scene_sync.state_path(target)
    original = path.read_bytes()
    result = io.StringIO()
    try:
        scene_sync.write(path, historical)
        with redirect_stdout(result):
            deploy.publish(target, key)
    finally:
        path.write_bytes(original)
        print(result.getvalue(), end="", flush=True)
    match = re.search(rf"^SUCCESS: Place {target['placeId']}, revision ([1-9][0-9]*)$",
                      result.getvalue(), re.MULTILINE)
    require(match and int(match[1]) > BASELINE_VERSION, "Roblox published revision unconfirmed")
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
        publish(target, key, args.output)
    else:
        readback(target, key, args.output)


if __name__ == "__main__":
    try:
        main()
    except (deploy.WorkspaceError, OSError, ValueError, KeyError, subprocess.CalledProcessError) as exc:
        sys.exit(f"ERROR: {exc}")
