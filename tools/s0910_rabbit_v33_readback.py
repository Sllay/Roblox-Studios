"""Read-only reconciliation of an accepted Rabbit V33 staging Place save.

There is deliberately no apply or SavePlaceAsync here. HTTP429 on the
post-save version check must never authorize re-publishing. Only prove which
version Roblox actually serves and verify immutable source/terrain/clip IDs.
"""
from __future__ import annotations

import json
import os
import time

import s0910_rabbit_v33_release as release


def checked_read(operation, name):
    for attempt in range(4):
        try:
            return operation()
        except Exception as exc:
            if "HTTP 429" not in str(exc) or attempt == 3:
                raise
            delay = (30, 60, 90)[attempt]
            print("RABBIT_V33_READBACK_RATE_LIMIT", name, "attempt", attempt + 1,
                  "retry_after_seconds", delay, flush=True)
            time.sleep(delay)


def main():
    receipt = json.loads(release.RECEIPT.read_text())
    old = json.loads(release.V32.read_text())
    proof = json.loads(release.PROOF.read_text())
    assert receipt["status"] == "requires_reconciliation"
    assert receipt["retryCount"] == 1 and receipt["retryAllowed"] is False
    assert receipt["saved"] is False and receipt["beforeVersion"] == 32
    assert receipt["expectedAfterVersion"] == 33
    assert receipt["targetUniverse"] == "10769712441"
    assert receipt["targetPlace"] == "93428341652658"
    assert receipt["modelAssetId"] == "87498816533548"
    ids = proof["animations"]
    assert proof["playbackVerified"] and receipt["animationIds"] == ids
    rows = release.sources()
    new_hashes = {row["id"]: row["hash"] for row in rows}
    assert new_hashes == receipt["sourceHashes"]
    assert receipt["terrainDigests"] == old["terrainDigests"]
    games, targets = release.load_all()
    target = release.resolve(games, targets, "mapa-principal", "main", "staging")
    assert target["universeId"] == "10769712441" and target["placeId"] == "93428341652658"
    key = os.environ["ROBLOX_OPEN_CLOUD_API_KEY"]

    # Allow endpoint budget to replenish after the prior successful apply.
    time.sleep(60)
    version = checked_read(lambda: release.latest(target, key), "latest")
    print("RABBIT_V33_REMOTE_VERSION", version, flush=True)
    if version != 33:
        raise RuntimeError("No V33 publication confirmation: staging version " + str(version))

    code = "do\n" + release.SCRIPT.read_text() + "\nend"
    opts = dict(sources=rows,
                oldHashes={row["id"]: old["sourceHashes"][row["id"]] for row in rows},
                modelAssetId=release.MODEL, animationIds=ids)
    result = checked_read(lambda: release.task(
        target, key, code, read_version=33, compile_source=True, mode="verify",
        expectedTerrain=receipt["terrainDigests"], **opts), "native-V33")
    assert result["verified"] and result["noPlaceWrites"]
    assert result["sourceHashes"] == receipt["sourceHashes"]
    assert result["terrainDigests"] == receipt["terrainDigests"]
    assert result["animationIds"] == ids
    assert result["geometry"]["bones"] == 19 and result["geometry"]["whiskers"] == 6
    assert result["geometry"]["meshCount"] == 9
    receipt.update(status="verified", saved=True, afterVersion=33,
                   verification=result, runtimeSmokeVerified=True,
                   reconciledWithoutReplay=True)
    release.atomic_json(release.RECEIPT, receipt)
    release.commit([release.RECEIPT], "evidence(s0910): confirm V33 by read-only native version and source readback")
    print("RABBIT_V33_STAGING_PUBLISHED", json.dumps({
        "status": receipt["status"], "version": receipt["afterVersion"],
        "noReplay": True, "modelAssetId": receipt["modelAssetId"],
        "animationIds": ids}, sort_keys=True), flush=True)


if __name__ == "__main__":
    main()
