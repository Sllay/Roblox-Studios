"""V41 experimental run: prevent severe torso/neck creasing seen in V40.

Builds a quadrupedal run with most forward lean on the root bone, instead of
folding the chest and head against the body. Real rig and real skinned mesh;
preview only. No source mesh edits and NO Roblox upload.
"""
from __future__ import annotations
import json
from pathlib import Path

import numpy as np
import rabbit_animation_author_v38 as native
import rabbit_animation_author_v40 as v40


class NativeRigWithRootPitch(native.NativeRig):
    """Backwards-compatible FK: only V41 Run supplies a Root rotation."""

    def evaluate(self, values):
        cache, local = {}, {}

        def visit(name):
            if name in cache:
                return cache[name]
            parent, rest = self.bones[name]
            prior = np.eye(4) if parent == "RootPart" else visit(parent)
            pose = prior @ rest
            if name == "Root":
                world = native.rotation(values.get("Root", [0, 0, 0]))
                delta = native.matrix(
                    r=pose[:3, :3].T @ world @ pose[:3, :3],
                    p=[0, float(values.get("RootYOffset", 0)), 0],
                )
            else:
                world = native.rotation(values.get(name, [0, 0, 0]))
                delta = native.matrix(r=pose[:3, :3].T @ world @ pose[:3, :3])
            local[name] = delta
            cache[name] = pose @ delta
            return cache[name]

        for name in self.bones:
            visit(name)
        return cache, local


# t, root_pitch, pelvis, chest, head, hop, front-contact-y,z, hind-contact-y,z
# Less extreme spine/head articulation than the inherited V38 run.
RUN = (
    (0.00, -1.04, -.22, -.11, .64, 0.00, .22, -1.04, .20, .52),
    (0.10, -1.09, -.25, -.12, .66, -.05, .20, -1.00, .16, .60),
    (0.21, -.99, -.13, -.07, .55, .12, .31, -1.12, .31, .69),
    (0.39, -.91, -.02, -.03, .48, .48, .41, -1.37, .45, .80),
    (0.54, -.96, -.06, -.05, .52, .54, .41, -1.44, .48, .74),
    (0.70, -1.01, -.13, -.08, .59, .31, .24, -1.42, .35, .64),
    (0.86, -1.07, -.23, -.11, .64, .03, .17, -1.08, .23, .53),
    (1.00, -1.04, -.22, -.11, .64, 0.00, .22, -1.04, .20, .52),
)


def run(rig):
    keys, report = [], []
    for t, root, pelvis, chest, head, hop, fy, fz, hy, hz in RUN:
        pose = {
            "Root": np.array([root, 0, 0]),
            "RootYOffset": hop,
            "Pelvis": np.array([pelvis, 0, 0]),
            "Chest": np.array([chest, 0, 0]),
            "Head": np.array([head, 0, 0]),
        }
        # A root-driven quadruped has a different rear-foot rest position
        # than V38's folded-spine rig. Set hind targets relative to the
        # evaluated bind limb, not legacy global Z positions.
        rest_fk, _ = rig.evaluate(pose)
        errors = []
        for kind, py, pz, width in (
            ("fore", fy, fz, .36), ("hind", hy, hz, .45)
        ):
            for side, sign in (("L", 1), ("R", -1)):
                target_z = (float(rest_fk["HindPaw_" + side][2, 3])
                            + .35 * (pz - .52)) if kind == "hind" else pz
                result, error = rig.ik(
                    pose, kind, side, [width * sign, py + hop, target_z]
                )
                pose.update(result)
                errors.append(error)
        max_error = max(errors)
        assert max_error < .25, ("v41_unreachable_contact", t, errors)
        assert abs(pelvis) <= .26 and abs(chest) <= .13 and abs(head) <= .67
        flight = max(0.0, min(1.0, hop / .54))
        pose["Ear_L"] = np.array([-.10 * flight, 0, -.035 * flight])
        pose["Ear_R"] = np.array([-.10 * flight, 0, .035 * flight])
        pose["Tail"] = np.array([.10 * flight, 0, 0])
        for side in ("L", "R"):
            pose["FrontPaw_" + side] = np.array([-.07 * flight, 0, 0])
            pose["HindPaw_" + side] = np.array([.065 * flight, 0, 0])
        fk, _ = rig.evaluate(pose)
        report.append({
            "phase": t, "root_pitch": root, "pelvis_pitch": pelvis,
            "chest_pitch": chest, "head_pitch": head,
            "hop": hop, "max_ik_error": max_error,
            "head_y": float(fk["Head"][1, 3]),
            "forepaw_y": float(fk["FrontPaw_L"][1, 3]),
            "hindpaw_y": float(fk["HindPaw_L"][1, 3]),
        })
        keys.append((t, pose))
    return keys, report


def main():
    # Keep V40 breathing, walk and grooming unchanged for A/B comparison.
    native.NativeRig = NativeRigWithRootPitch
    v40.run = run
    v40.CLIPS["Run"] = (.68, 64, True, 1)
    v40.main()
    import sys
    out = Path(sys.argv[2])
    manifest_path = out / "manifest.json"
    manifest = json.loads(manifest_path.read_text())
    manifest["stage"] = "v41_run_review_only_real_mesh_no_publish"
    manifest["gait_contract"]["Run"] = "quadruped_root_tilt_limited_spine_and_head"
    manifest["run_rebuild"] = {
        "legacy_v38_run_used": False,
        "root_rotation_enabled": True,
        "spine_and_head_angle_guards": True,
        "skin_weights_changed": False,
    }
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
    print("RABBIT_V41_RUN_REBUILD_SOURCE_ONLY", flush=True)


if __name__ == "__main__":
    main()
