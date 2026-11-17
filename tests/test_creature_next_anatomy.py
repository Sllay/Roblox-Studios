import unittest
from tools.creature_factory.next.anatomy import *
from tools.creature_factory.next.contracts import ContractError
class AnatomyTests(unittest.TestCase):
    def test_arbitrary_monster(self):
        parts=[Part("body","body")]
        for kind,n in (("head",2),("leg",6),("wing",4),("tentacle",7)):
            parts.extend(Part(f"{kind}_{i}",kind,"body",thin=kind=="wing",protected=kind in ("wing","tentacle"),articulation="flexible") for i in range(n))
        a=Anatomy(parts,{"head":2,"leg":6,"wing":4,"tentacle":7})
        self.assertEqual(a.summary()["counts"]["wing"],4);self.assertFalse(a.summary()["geometry_verified"])
    def test_cycle_and_count_rejected(self):
        with self.assertRaises(ContractError):Anatomy([Part("body","body"),Part("a","leg","b"),Part("b","leg","a")])
        with self.assertRaises(ContractError):Anatomy([Part("body","body")],{"leg":6})
    def test_mirror_reciprocity(self):
        with self.assertRaises(ContractError):Anatomy([Part("body","body"),Part("a","wing","body","left","b"),Part("b","wing","body","right")])
        a=Anatomy([Part("body","body"),Part("a","wing","body","left","b"),Part("b","wing","body","right","a")])
        self.assertEqual(len(a.parts),3)
    def test_unknown_not_absence_or_approval(self):
        a=Anatomy([Part("body","body"),Part("wing","wing","body")])
        r=check_part_evidence(a,[{"part_id":"body","state":"present","provenance":"reviewed_geometry"},{"part_id":"wing","state":"unknown","provenance":"detector"}])
        self.assertEqual(r["unverified"],["wing"]);self.assertFalse(r["automatic_artistic_approval"])
    def test_no_fake_confirmation(self):
        a=Anatomy([Part("body","body")])
        self.assertEqual(check_part_evidence(a,[{"part_id":"body","state":"present","provenance":"detector"}])["status"],"incomplete")
