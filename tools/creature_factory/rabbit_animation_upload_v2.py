"""Journal, upload and probe four new Rabbit animation assets, then bind their IDs.

Never overwrite the V32 receipts or re-upload on uncertainty. The old 6 clips
remain immutable; Peck, Flap and Death are reused. Only a verified detached
playback result can update the CreatureRegistry for the V33 staging release.
"""
from __future__ import annotations

import json
from pathlib import Path

import rabbit_animation_author_v2
import rabbit_animation_upload as original

ROOT = Path(__file__).resolve().parents[2]
original.DIR = ROOT / "asset-library/candidates/rabbit-v3-cartoon-v2-mobile-lod0/native-animations-v2"
original.RECEIPTS = ROOT / "asset-library/roblox-receipts/s0910-rabbit-v2"
original.api.RECEIPTS = original.RECEIPTS
original._author_main = rabbit_animation_author_v2.main
REGISTRY = ROOT / "games/maps/mapa-principal/game/places/main/src/ServerScriptService/CreatureFramework/CreatureRegistry.luau"
PREVIOUS = ROOT / "asset-library/roblox-receipts/s0910-rabbit/rabbit-animations-published.json"
V32 = ROOT / "games/maps/mapa-principal/docs/s09/publication-rabbit-v32.json"


def bind_verified_clips() -> None:
    last = json.loads(V32.read_text())
    assert last["status"] == "verified" and last["afterVersion"] == 32
    previous = json.loads(PREVIOUS.read_text())
    receipt = json.loads((original.RECEIPTS / "rabbit-animations-published.json").read_text())
    assert receipt["playbackVerified"] and receipt["stagingPlaceWritten"] is False
    assert receipt["source_sha256"] == previous["source_sha256"]
    ids = receipt["animations"]
    assert set(ids) == {"Idle", "Walk", "Run", "ScratchEar"}
    assert len(set(ids.values())) == 4 and all(str(x).isdigit() for x in ids.values())
    source = REGISTRY.read_text(encoding="utf-8")
    original_source = source
    for key in ("Idle", "Walk", "Run"):
        old = key + '="' + previous["animations"][key] + '"'
        new = key + '="' + ids[key] + '"'
        if old in source:
            assert source.count(old) == 1, key
            source = source.replace(old, new)
        else:
            assert new in source, "Unexpected clip already in registry: " + key
    scratch = 'ScratchEar="' + ids["ScratchEar"] + '"'
    if "ScratchEar=" not in source:
        old = 'Peck="' + previous["animations"]["Peck"] + '"'
        assert source.count(old) == 1
        source = source.replace(old, scratch + ",\n             " + old)
    else:
        assert scratch in source, "Scratch asset identity drift"
    assert 'Death="' + previous["animations"]["Death"] + '"' in source
    assert 'Flap="' + previous["animations"]["Flap"] + '"' in source
    if source != original_source:
        REGISTRY.write_text(source, encoding="utf-8")
        original.persist([REGISTRY], "feat(s0910): bind native-verified hop and ear scratch animation IDs")
    print("RABBIT_V2_CLIPS_BOUND", json.dumps(ids, sort_keys=True), flush=True)


if __name__ == "__main__":
    original.main()
    bind_verified_clips()
