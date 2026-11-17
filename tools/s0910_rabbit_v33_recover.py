"""Reconcile a V33 task-creation HTTP 429, then allow ONE proven-safe retry.

Never replay an uncertain accepted Place task. A retry is permitted only when
the prior error occurred at task creation (429, no task ID), the saved receipt
has no success marker, a full task timeout has passed, and two independent
remote version reads agree V32 is still current. If V33 already exists, only
read it back. No production Place is ever touched.
"""
from __future__ import annotations

import json
import os
import subprocess
import time

import s0910_rabbit_v33_release as release


def require(cond, message):
    if not cond:
        raise RuntimeError(message)


def main():
    old = json.loads(release.V32.read_text())
    require(old["status"] == "verified" and old["afterVersion"] == 32, "V32 prerequisite")
    receipt = json.loads(release.RECEIPT.read_text())
    require(receipt["targetUniverse"] == "10769712441" and receipt["targetPlace"] == "93428341652658", "Staging identity")
    require(receipt["beforeVersion"] == 32 and receipt["expectedAfterVersion"] == 33, "V33 scope")
    require(receipt["saved"] is False and receipt["status"] == "requires_reconciliation", "Only unconfirmed V33")
    require(receipt.get("retryCount", 0) == 0, "A recovery attempt was already made; do not replay")
    require(receipt.get("retryAllowed") is False, "Journal must be fail-closed")
    require(str(receipt.get("error", "")).startswith("Roblox API HTTP 429:"), "Only task-creation rate limit is recoverable automatically")

    proof = json.loads(release.PROOF.read_text())
    ids = proof["animations"]
    require(proof["playbackVerified"] and proof["stagingPlaceWritten"] is False, "Native assets")
    require(receipt["animationIds"] == ids and set(ids) == {"Idle", "Walk", "Run", "ScratchEar"}, "Published animation identity")
    rows = release.sources()
    new_hashes = {row["id"]: row["hash"] for row in rows}
    require(receipt["sourceHashes"] == new_hashes, "Source drift after failed write")
    require(len(rows) == 2 and all(row["id"] in old["sourceHashes"] for row in rows), "Patch scope")
    require(receipt["terrainDigests"] == old["terrainDigests"], "Terrain baseline changed")

    games, targets = release.load_all()
    target = release.resolve(games, targets, "mapa-principal", "main", "staging")
    require(target["universeId"] == receipt["targetUniverse"] and target["placeId"] == receipt["targetPlace"], "Target drift")
    key = os.environ["ROBLOX_OPEN_CLOUD_API_KEY"]
    code = "do\n" + release.SCRIPT.read_text() + "\nend"
    opts = dict(sources=rows, oldHashes={row["id"]: old["sourceHashes"][row["id"]] for row in rows},
                modelAssetId=release.MODEL, animationIds=ids)

    def native(mode, version, **kwargs):
        return release.task(target, key, code, read_version=version, compile_source=True, mode=mode, **opts, **kwargs)

    def check_verified():
        result = native("verify", 33, expectedTerrain=receipt["terrainDigests"])
        require(result["verified"] and result["sourceHashes"] == new_hashes, "V33 readback sources")
        require(result["terrainDigests"] == receipt["terrainDigests"], "V33 readback terrain")
        require(result["animationIds"] == ids, "V33 readback animation IDs")
        require(result["geometry"]["bones"] == 19 and result["geometry"]["whiskers"] == 6, "V33 rig")
        require(release.latest(target, key) == 33, "Staging head changed after V33 verification")
        receipt.update(status="verified", saved=True, afterVersion=33, verified=True,
                       verification=result, runtimeSmokeVerified=True, recovery="readback_without_new_post")
        release.atomic_json(release.RECEIPT, receipt)
        release.commit([release.RECEIPT], "evidence(s0910): V33 reconciled by native readback")
        print("RABBIT_V33_RECONCILED", json.dumps({"version": 33, "saved": True}), flush=True)

    latest = release.latest(target, key)
    if latest == 33:
        check_verified()
        return
    require(latest == 32, "Unknown remote Place version: " + str(latest))

    # A rejected task-creation HTTP429 produced no operation path. The previous
    # intent commit is dated; wait out the full 90s task timeout + margin.
    timestamp = int(subprocess.check_output(
        ["git", "log", "-1", "--format=%ct", "--", str(release.RECEIPT.relative_to(release.ROOT))],
        cwd=release.ROOT, text=True).strip())
    remaining = 120 - (time.time() - timestamp)
    if remaining > 0:
        time.sleep(remaining)
    require(release.latest(target, key) == 32, "Staging advanced during cooldown")
    time.sleep(15)
    require(release.latest(target, key) == 32, "Staging changed between independent readbacks")

    # Confirm native V32 remains the exact base and all preview gates still pass.
    preview = native("preview", 32)
    require(preview["readyForStaging"] and preview["noPlaceWrites"] and
            preview["movementProbe"] and preview["brainProbe"], "Native preview must pass")
    require(preview["sourceHashes"] == new_hashes and preview["animationIds"] == ids, "Preview code/animations")
    require(preview["terrainDigests"] == receipt["terrainDigests"], "Preview terrain")
    require(release.latest(target, key) == 32, "Staging head changed after preview")

    receipt.update(status="reconciled_single_retry_intent", retryCount=1,
                   priorError=receipt["error"], recovery="task_create_http429_remote_still_v32",
                   recoveryRunId=os.environ.get("GITHUB_RUN_ID"))
    release.atomic_json(release.RECEIPT, receipt)
    release.commit([release.RECEIPT], "intent(s0910): one reconciled V33 retry after rejected HTTP429")
    try:
        saved = native("apply", None, expectedTerrain=receipt["terrainDigests"],
                       confirmStaging=True, journal=release.OUT / "recovery-save-task.json")
        release.write(release.OUT / "recovery-save-result.json", saved)
        require(saved["saved"] and saved["rabbitModelId"] == release.MODEL, "V33 native save result")
        require(release.latest(target, key) == 33, "V33 not confirmed after retry")
        check_verified()
    except Exception as exc:
        receipt.update(status="requires_reconciliation", error=str(exc)[:500], saved=False,
                       retryCount=1, recovery="single_retry_attempted_no_repost")
        release.atomic_json(release.RECEIPT, receipt)
        release.commit([release.RECEIPT], "evidence(s0910): V33 retry uncertain - manual reconciliation required")
        raise


if __name__ == "__main__":
    main()
