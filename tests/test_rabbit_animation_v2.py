"""Numerical and serialization gates for Rabbit V2 animation poses (no Roblox writes)."""
from __future__ import annotations

import math
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/creature_factory"))
import rabbit_animation_author_v2 as rabbit


class RabbitHopTest(unittest.TestCase):
    def test_closed_loops(self):
        for clip in ("Idle", "Walk", "Run"):
            for bone in rabbit.original.EXPECTED:
                a, b = rabbit.motion(clip, bone, 0), rabbit.motion(clip, bone, 1)
                self.assertLess(max(abs(x - y) for x, y in zip(a, b)), 1e-9, (clip, bone))

    def test_hind_legs_are_synchronized(self):
        for clip in ("Walk", "Run"):
            for t in (.08, .17, .31, .45, .73, .91):
                for chain in ("Hip", "Shin", "HindPaw"):
                    left = rabbit.motion(clip, chain + "_L", t)
                    right = rabbit.motion(clip, chain + "_R", t)
                    self.assertEqual(left, right, (clip, chain, t))
            self.assertGreater(rabbit.motion(clip, "Root", .42)[1], .09)

    def test_run_is_a_stronger_four_leg_bound(self):
        walk = rabbit.motion("Walk", "Root", .42)[1]
        run = rabbit.motion("Run", "Root", .42)[1]
        self.assertGreater(run, walk * 2)
        for bone in ("Shoulder_L", "Shoulder_R", "Forearm_L", "Forearm_R", "FrontPaw_L", "FrontPaw_R"):
            self.assertGreater(
                max(abs(rabbit.motion("Run", bone, t)[i] - rabbit.motion("Run", bone, 0)[i])
                    for t in (.31, .48, .72) for i in (5, 6, 9, 10)),
                .05,
                bone,
            )

    def test_scratch_lifts_only_left_hind_leg_and_droops_left_ear(self):
        left = rabbit.motion("ScratchEar", "Hip_L", .5)
        right = rabbit.motion("ScratchEar", "Hip_R", .5)
        ear = rabbit.motion("ScratchEar", "Ear_L", .5)
        self.assertGreater(abs(left[10]), .5)
        self.assertEqual(right, rabbit.original.cframe_xyz())
        self.assertGreater(abs(ear[10]), .3)
        self.assertFalse(rabbit.CLIPS["ScratchEar"][2])
        self.assertEqual(rabbit.CLIPS["ScratchEar"][3], 2)
        for bone in rabbit.original.EXPECTED:
            self.assertLess(max(abs(x - y) for x, y in zip(
                rabbit.motion("ScratchEar", bone, 0),
                rabbit.motion("ScratchEar", bone, 1))), 1e-9)

    def test_real_rig_export(self):
        glb = ROOT / "asset-library/candidates/rabbit-v3-cartoon-v2-mobile-lod0/asset.glb"
        if not glb.is_file():
            self.skipTest("GLB not present in this test runtime")
        old_argv = sys.argv
        with tempfile.TemporaryDirectory() as td:
            try:
                sys.argv = ["rabbit_animation_author_v2.py", str(glb), td]
                rabbit.main()
            finally:
                sys.argv = old_argv
            import json
            import xml.etree.ElementTree as ET
            report = json.loads((Path(td) / "manifest.json").read_text())
            self.assertEqual(set(report["clips"]), set(rabbit.CLIPS))
            for name, clip in report["clips"].items():
                xml = ET.parse(Path(td) / clip["file"]).getroot()
                keyframes = xml.findall('.//Item[@class="Keyframe"]')
                self.assertEqual(len(keyframes), clip["frames"])
                self.assertEqual(clip["poseCount"], 20)
                self.assertTrue(all(len(k.findall('.//Item[@class="Pose"]')) == 20 for k in keyframes))
                self.assertGreater(clip["maxMotionComponent"], .01)


if __name__ == "__main__":
    unittest.main()
