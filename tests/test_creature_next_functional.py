import unittest
from tools.creature_factory.next.functional_gate import evaluate_functional_parts
class FunctionalGateTests(unittest.TestCase):
    def test_silhouette_does_not_confirm_parts(self):
        r=evaluate_functional_parts(["foreleg_l","foreleg_r"],{"foreleg_l":{"state":"present","provenance":"silhouette"}},{})
        self.assertEqual(r["status"],"blocked_functional_anatomy")
    def test_real_movement_needed(self):
        o={"tail":{"state":"present","provenance":"reviewed_geometry","articulated":True}}
        self.assertEqual(evaluate_functional_parts(["tail"],o,{})["status"],"blocked_functional_anatomy")
        p={"tail":{"state":"passed","provenance":"evaluated_mesh","moved_vertices":42,"max_displacement":.2,"static_leakage":0,"leakage_limit":.001}}
        self.assertEqual(evaluate_functional_parts(["tail"],o,p)["status"],"functional_evidence_complete")
        p["tail"]["static_leakage"]=.1
        self.assertEqual(evaluate_functional_parts(["tail"],o,p)["status"],"blocked_functional_anatomy")
