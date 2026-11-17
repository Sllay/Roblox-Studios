"""V39 rabbit animation preview: upright idle/walk/groom; quadrupedal run.

Source-only. Does not upload an animation, mutate the original mesh/weights,
or write any Roblox Place. V38's published receipts remain immutable.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np

import rabbit_animation_author as serializer
import rabbit_animation_author_v38 as native

CLIPS = {
    "Idle": (3.0, 48, True, 0),
    "Walk": (0.94, 64, True, 1),
    "Run": (0.64, 48, True, 1),
    "ScratchEar": (2.1, 72, False, 2),
}

# The imported native rest pose is already bipedal: head ~1.86 studs high,
# hind toes ~0.24, front toes ~1.12. V38 erroneously used a -1.25-radian
# quadruped torso pitch as its idle, walk and grooming base.
STAND = {
    "Pelvis": [-0.06, 0, 0],
    "Chest": [0.025, 0, 0],
    "Head": [0.035, 0, 0],
    "RootYOffset": 0.0,
}

# phase, vertical hop, hip pitch, shin pitch, hind-toe counter pitch,
# torso pitch, subtle near-side shoulder sway. Both hind legs propel the hop;
# the forelimbs are carried, NEVER used as support during Walk.
WALK_BLOCKS = (
    (0.00, 0.00,  0.06, -0.08, 0.02,  0.00,  0.00),
    (0.12,-0.045, 0.18, -0.25, 0.12,  0.07,  0.00),
    (0.23, 0.12, -0.12,  0.12,-0.07, -0.09, -0.025),
    (0.40, 0.48, -0.23,  0.23,-0.12, -0.11,  0.035),
    (0.57, 0.44, -0.12,  0.09,-0.04, -0.075, 0.025),
    (0.73, 0.16,  0.14, -0.16, 0.08,  0.04,  0.00),
    (0.86, 0.00,  0.09, -0.12, 0.05,  0.02,  0.00),
    (1.00, 0.00,  0.06, -0.08, 0.02,  0.00,  0.00),
)


def standing():
    return {name: np.asarray(v, dtype=float).copy()
            for name, v in STAND.items()}


def idle(rig):
    keys = []
    for phase, breathe in ((0, 0), (.25, 1), (.5, 0), (.75, -1), (1, 0)):
        pose = standing()
        pose["Chest"][0] += .012 * breathe
        pose["Head"][0] -= .008 * breathe
        pose["Ear_L"] = np.array([.025 * breathe, 0, 0])
        pose["Ear_R"] = np.array([.025 * breathe, 0, 0])
        keys.append((phase, pose))
    return keys, []


def walk(rig):
    keys = []
    report = []
    for t, y, hip, shin, toe, pitch, swing in WALK_BLOCKS:
        pose = standing()
        pose["RootYOffset"] = y
        pose["Pelvis"][0] += .72 * pitch
        pose["Chest"][0] += .28 * pitch
        pose["Head"][0] -= .6 * pitch
        for side in ("L", "R"):
            pose["Hip_" + side] = np.array([hip, 0, 0])
            pose["Shin_" + side] = np.array([shin, 0, 0])
            pose["HindPaw_" + side] = np.array([toe, 0, 0])
        # Tiny hand sway for balance, with no reaching or planted forelegs.
        pose["Shoulder_L"] = np.array([swing, 0, 0])
        pose["Shoulder_R"] = np.array([-swing, 0, 0])
        pose["Ear_L"] = np.array([-.045 * max(y, 0), 0, 0])
        pose["Ear_R"] = np.array([-.045 * max(y, 0), 0, 0])
        fk, _ = rig.evaluate(pose)
        report.append({
            "phase": t, "root_y": y,
            "head_y": float(fk["Head"][1, 3]),
            "front_left_y": float(fk["FrontPaw_L"][1, 3]),
            "front_right_y": float(fk["FrontPaw_R"][1, 3]),
            "hind_left_y": float(fk["HindPaw_L"][1, 3]),
            "hind_right_y": float(fk["HindPaw_R"][1, 3]),
            "hind_powered": True, "front_support": False,
        })
        keys.append((t, pose))
    return keys, report


def ear_tip(fk, side="R"):
    # Proxy for the visibly deforming ear mid/tip, not the ear pivot (which
    # cannot translate when a bone rotates).
    mat = fk["Ear_" + side]
    return mat[:3, 3] + .68 * mat[:3, 1]


def groom(rig):
    home = standing()
    fk0, _ = rig.evaluate(home)
    head = fk0["Head"][:3, 3]
    # Target beside upper cheek/lower ear. Never pull the hind leg up.
    target = head + np.array([-.23, .44, -.05], dtype=float)
    contact, error = rig.ik(home, "fore", "R", target)
    assert error < .16, ("front_paw_outside_reach", error)
    keys, report = [], []
    for t, raised, brush in (
        (0, 0, 0), (.15, .4, 0), (.29, 1, .2), (.39, 1, 1),
        (.50, 1, .12), (.60, 1, 1), (.71, 1, .2),
        (.85, .5, 0), (1, 0, 0),
    ):
        pose = {
            bone: (1-raised)*np.asarray(home.get(bone, [0, 0, 0]), dtype=float)
                  + raised*np.asarray(contact.get(bone, [0, 0, 0]), dtype=float)
            for bone in native.JOINTS
        }
        pose["RootYOffset"] = 0.
        # Ear folds forward and downward TO the reaching front paw, instead
        # of the torso/head folding into an unreachable hand.
        pose["Ear_R"] = np.array([-.90*raised-.25*brush, 0, .045*raised])
        pose["FrontPaw_R"] = np.array([-.055*brush, 0, 0])
        pose["Forearm_R"] = np.asarray(pose["Forearm_R"])+[.055*brush, 0, 0]
        fk, _ = rig.evaluate(pose)
        hand = fk["FrontPaw_R"][:3, 3]
        report.append({
            "phase": t, "raised": raised, "brush": brush,
            "right_forepaw": hand.round(5).tolist(),
            "ear_tip": ear_tip(fk).round(5).tolist(),
            "head_y": float(fk["Head"][1, 3]),
            "hind_left": fk["HindPaw_L"][:3, 3].round(5).tolist(),
            "hind_right": fk["HindPaw_R"][:3, 3].round(5).tolist(),
        })
        keys.append((t, pose))
    for name in native.JOINTS:
        assert np.allclose(keys[0][1][name], keys[-1][1][name]), name
    return keys, report


def run(rig):
    # Preserve V38's actual four-contact IK for running only. Do not recast
    # this quadrupedal motion as the Idle or Walk home pose.
    return native.blocks(rig, "Run")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("source_glb", type=Path)
    ap.add_argument("out_dir", type=Path)
    args = ap.parse_args()
    rig = native.NativeRig()
    authors = {"Idle": idle, "Walk": walk, "Run": run,
               "ScratchEar": groom}
    native.RIG = rig
    native.CACHE.clear()
    native.EVIDENCE.clear()
    for clip, fn in authors.items():
        keys, report = fn(rig)
        native.EVIDENCE[clip] = {"keys": keys, "blocking": report}
    serializer.CLIPS = CLIPS
    serializer.motion = native.motion
    previous = sys.argv
    sys.argv = ["rabbit_animation_author.py",
                str(args.source_glb), str(args.out_dir)]
    try:
        serializer.main()
    finally:
        sys.argv = previous
    manifest_path = args.out_dir / "manifest.json"
    manifest = json.loads(manifest_path.read_text())
    manifest["stage"] = "v39_preview_only_not_uploaded"
    manifest["gait_contract"] = {
        "Idle": "upright_hind_support",
        "Walk": "upright_hind_hop_front_hands_carried",
        "Run": "quadrupedal_four_contact",
        "ScratchEar": "stationary_upright_right_forepaw_ear_fold",
    }
    for clip, row in manifest["clips"].items():
        samples = []
        for i in range(CLIPS[clip][1]+1):
            t = i/CLIPS[clip][1]
            pose, fk, _ = native.CACHE[(clip, round(t, 8))]
            samples.append({
                "t": round(t, 5),
                "root_y": round(float(pose["RootYOffset"]), 5),
                "head": fk["Head"][:3, 3].round(5).tolist(),
                "forepaw": fk["FrontPaw_L"][:3, 3].round(5).tolist(),
                "forepaw_right": fk["FrontPaw_R"][:3, 3].round(5).tolist(),
                "hindpaw": fk["HindPaw_L"][:3, 3].round(5).tolist(),
                "hindpaw_right": fk["HindPaw_R"][:3, 3].round(5).tolist(),
                "ear_tip_right": ear_tip(fk).round(5).tolist(),
            })
        row["samples"] = samples
        row["blocking"] = native.EVIDENCE[clip]["blocking"]
    manifest_path.write_text(json.dumps(manifest, indent=2)+"\n")
    print("RABBIT_V39_SOURCE_ONLY",
          json.dumps({k: {"frames": v["frames"], "duration": v["duration"]}
                      for k, v in manifest["clips"].items()}), flush=True)


if __name__ == "__main__":
    main()
