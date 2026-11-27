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
CANDIDATE = "46594201fe56d6f49707088e3a919d20977d8f13"
STAGING_UNIVERSE = "10769712413"
STAGING_PLACE = "90623742498445"
# Verified with the official Place Provision inventory run 45681890920.
OWNER = ("User", "8136365379")
SCRIPT_CLASSES = {"Script", "LocalScript", "ModuleScript"}
BASELINE_VERSION = 22
BASELINE_DIGEST = "3e815508daf96d1faace1f57d6bbe24342a6bcb854e221dadfd4d629c1f48aa9"
ROLLBACK_SHA = "b712a6f6c44e3d91a891ab4db73294aa0e1dcaf9"
ROLLBACK_BUILD_SHA = "cc9f62b5fdb13652474ce2b967d39a1869181f082ae598324c528e540483c126"

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
            f"This preview only replaces the reviewed staging v{BASELINE_VERSION} baseline")
    return target


def check_identity(target, key):
    identity = place_provision.task(target, key, "identity")
    require(identity.get("verified") is True, "Staging identity unverified")
    require((identity["creatorType"], identity["creatorId"]) == OWNER, "Staging owner mismatch")
    require(identity["loadedVersion"] == BASELINE_VERSION, f"Staging is no longer at v{BASELINE_VERSION}")


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


def vegetation_meshes(artifact):
    compiled = ElementTree.parse(artifact)
    require(compiled.findtext(".//Item[@class='Terrain']/Properties/bool[@name='Decoration']") == "true",
            "Native grass must be enabled in the build")
    storage = compiled.find("./Item[@class='ServerStorage']")
    require(storage is not None, "ServerStorage missing from the build")
    folder = next((item for item in storage.findall("Item[@class='Folder']")
                   if item.findtext("Properties/string[@name='Name']") == "ERVegetation"), None)
    require(folder is not None, "Vegetation templates missing from the build")
    meshes = {}
    models = folder.findall("Item[@class='Model']")
    for model in models:
        model_name = model.findtext("Properties/string[@name='Name']")
        for mesh in model.findall("Item[@class='MeshPart']"):
            name = mesh.findtext("Properties/string[@name='Name']")
            meshes[f"{model_name}/{name}"] = mesh.findtext("Properties/Content[@name='MeshContent']/uri")
    require(len(models) == 8 and len(meshes) == 12 and all(meshes.values()), "Incomplete vegetation templates")
    return meshes


def verify_vegetation(expected, observed):
    meshes = {}
    grass = False
    for row in observed["records"].values():
        if row.get("service") == "Workspace" and row.get("class") == "Terrain":
            grass = row["properties"].get("decoration") is True
        if row.get("service") != "ServerStorage" or row.get("class") != "MeshPart":
            continue
        path = [part["name"] for part in row["path"]]
        if len(path) == 3 and path[0] == "ERVegetation":
            meshes["/".join(path[1:])] = row["properties"].get("meshId")
    require(meshes == expected, "Published vegetation mesh references differ from the checked build")
    require(grass, "Native grass is disabled in the published Terrain")


def publish(target, key, out):
    artifact = target["file"]
    hashes = script_hashes(artifact)
    meshes = vegetation_meshes(artifact)
    rollback_file = out / f"entre-reinos-v{BASELINE_VERSION}-rollback.rbxlx"
    rollback_build = hashlib.sha256(rollback_file.read_bytes()).hexdigest()
    require(rollback_build == ROLLBACK_BUILD_SHA, f"Rollback differs from the published v{BASELINE_VERSION} build")
    rollback_scripts = script_hashes(rollback_file)
    subprocess.run([sys.executable, str(deploy.ROOT / "tools/script_quality.py")], check=True)

    check_identity(target, key)
    historical = scene_sync.capture(target, key, read_version=BASELINE_VERSION)
    require(historical["loadedVersion"] == BASELINE_VERSION and historical["stateDigest"] == BASELINE_DIGEST,
            f"Historical v{BASELINE_VERSION} rollback scene not verified")
    verify_scripts(rollback_scripts, historical)
    scene_sync.write(out / "baseline.json", historical)
    rollback = {
        "candidate": ROLLBACK_SHA, "revision": BASELINE_VERSION, "sceneDigest": historical["stateDigest"],
        "artifactSha256": rollback_build,
        "scriptsVerified": len(rollback_scripts),
    }
    scene_sync.write(out / "rollback.json", rollback)
    print("PREVIEW_ROLLBACK", json.dumps(rollback), flush=True)

    # Refresh the disposable checkout's inventory so the official publisher
    # can compare the current scene immediately before the Assets API write.
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
        "scriptHashes": hashes, "vegetationMeshes": meshes,
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
    verify_vegetation(receipt["vegetationMeshes"], observed)
    require(observed["records"]["environment:workspace"]["StreamingEnabled"] is True,
            "Streaming disabled in published preview")
    proof = {k: receipt[k] for k in ("candidate", "universeId", "placeId", "revision", "artifactSha256")}
    proof.update(scriptsVerified=len(receipt["scriptHashes"]), vegetationMeshesVerified=len(receipt["vegetationMeshes"]),
                 nativeGrass=True, sceneDigest=observed["stateDigest"],
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
