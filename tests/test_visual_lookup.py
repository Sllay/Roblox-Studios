import json, sys, unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(ROOT/"tools/assets"),str(ROOT/"tools")]
from visual_lookup import lookup
from visual_memory import apply_reviews,evidence_key
from PIL import Image

class VisualLookupTests(unittest.TestCase):
    def setUp(self):
        self.registry=json.loads((ROOT/"games/maps/mapa-principal/game/assets/visual-reviews/79689531752352.json").read_text())
    def test_inventory_and_lookup(self):
        self.assertEqual(len(self.registry["reviews"]),23)
        self.assertEqual(len(self.registry["auxiliaryModelsDetails"]),6)
        result=lookup(self.registry,"pinheiro",biome="floresta-coniferas")
        self.assertEqual({x["name"] for x in result},{"Tree_10","Tree_20"})
        self.assertEqual(lookup(self.registry,name="Tree_17")[0]["selector"][-1]["name"],"Tree_17")
        self.assertTrue(all(r["requiresReauditBeforeImport"] for r in result))
        self.assertFalse(lookup(self.registry,biome="praia-de-coqueiros"))
    def test_reuse_and_invalidate(self):
        im=Image.new("RGB",(2,2),"gray")
        model={"name":"Tree_01","modelKey":"key","classification":"candidate","components":[{"meshAssetId":"123"}],"visual":{"status":"partial_evidence","evidence":[]},"securityStatus":"not_approved"}
        catalog={"packAssetId":"1","models":[model]}
        registry={"schemaVersion":1,"packAssetId":"1","sourceRun":"run","reviews":[{"name":"Tree_01","modelKey":"key","evidenceKey":evidence_key(model,{"123":im}),"visual":{"status":"geometry_reviewed","description":"shape"}}]}
        self.assertEqual(apply_reviews(catalog,registry,{"123":im}),1)
        self.assertEqual(model["visual"]["description"],"shape")
        self.assertEqual(model["securityStatus"],"not_approved")
        self.assertEqual(apply_reviews(catalog,registry,{"123":Image.new("RGB",(2,2),"red")}),0)
        self.assertEqual(model["visual"]["status"],"stale_review")
