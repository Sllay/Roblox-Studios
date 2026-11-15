import ast, json, pathlib, unittest
ROOT=pathlib.Path(__file__).resolve().parents[2]
class OrganicContract(unittest.TestCase):
    def test_sources(self):
        for name in ("rabbit_organic_reference.py","rabbit_organic_blender.py"):
            ast.parse((ROOT/"tools/creature_factory"/name).read_text())
    def test_budget_and_approval(self):
        q=json.loads((ROOT/"asset-library/creature-queue/rabbit-v2.json").read_text())
        self.assertEqual(q["runtimeVertexBudget"],20000)
        self.assertEqual(q["whiskers"]["count"],6)
        self.assertTrue(q["approvalRequired"]);self.assertFalse(q["publication"])
    def test_old_rejected(self):
        r=json.loads((ROOT/"asset-library/reviews/rabbit-v1-43678677522-1.json").read_text())
        self.assertEqual(r["artisticStatus"],"rejected");self.assertFalse(r["publicationAllowed"])
if __name__=="__main__":unittest.main()
