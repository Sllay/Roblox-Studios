"""Publish V37 frontpaw grooming and broad rabbit bounds ONLY after visual approval.

Upload is one-shot and journalled. It never writes a Roblox Place; staging V34
is a separate audited step initiated only after all four clips play natively.
The verified V33 skinned model is deliberately retained, avoiding model swap.
"""
from __future__ import annotations
import json,sys
from pathlib import Path
import rabbit_animation_author_v37
import rabbit_animation_upload as original

ROOT=Path(__file__).resolve().parents[2]
DIR=ROOT/"asset-library/candidates/rabbit-v3-cartoon-v2-mobile-lod0/native-animations-v37"
RECEIPTS=ROOT/"asset-library/roblox-receipts/s0910-rabbit-v37"
REGISTRY=ROOT/"games/maps/mapa-principal/game/places/main/src/ServerScriptService/CreatureFramework/CreatureRegistry.luau"
PREVIOUS=ROOT/"games/maps/mapa-principal/docs/s09/publication-rabbit-v33.json"
PROOF_SOURCE=ROOT/"asset-library/roblox-receipts/s0910-rabbit/rabbit-native-proof.json"

original.DIR=DIR
original.RECEIPTS=RECEIPTS
original.api.RECEIPTS=RECEIPTS
original._author_main=rabbit_animation_author_v37.main

def bind():
    before=json.loads(PREVIOUS.read_text())
    assert before["status"]=="verified" and before["saved"] is True and before["afterVersion"]==33
    existing=before["animationIds"]
    receipt=json.loads((RECEIPTS/"rabbit-animations-published.json").read_text())
    assert receipt["playbackVerified"] and receipt["stagingPlaceWritten"] is False
    assert receipt["source_sha256"]==original.SHA
    ids=receipt["animations"]
    assert set(ids)=={"Idle","Walk","Run","ScratchEar"}
    assert len(set(ids.values()))==4
    source=REGISTRY.read_text(encoding="utf-8")
    original_source=source
    for key,old in existing.items():
        new=ids[key]
        assert new!=old and str(new).isdigit()
        oldvalue=key+'="'+old+'"'
        newvalue=key+'="'+new+'"'
        if oldvalue in source:
            assert source.count(oldvalue)==1
            source=source.replace(oldvalue,newvalue)
        else:
            assert newvalue in source,'Unknown prior animation binding '+key
    assert 'Death="113737115841702"' in source
    if source!=original_source:
        REGISTRY.write_text(source,encoding="utf-8")
        original.persist([REGISTRY],"feat(s0910): bind V37 native-verified quadruped hop and grooming clips")
    print("RABBIT_V37_NATIVE_CLIPS_BOUND",json.dumps(ids,sort_keys=True),flush=True)

def main():
    native=json.loads(PROOF_SOURCE.read_text())
    assert native["bones"]==19 and native["whiskers"]==6 and native["poseRoundtrip"]
    RECEIPTS.mkdir(parents=True,exist_ok=True)
    dest=RECEIPTS/"rabbit-native-proof.json"
    if dest.exists():
        assert dest.read_bytes()==PROOF_SOURCE.read_bytes()
    else:
        dest.write_bytes(PROOF_SOURCE.read_bytes())
        original.persist([dest],"evidence(s0910): unchanged 19-bone rabbit native proof for V37")
    original.main()
    bind()

if __name__=="__main__":
    main()
