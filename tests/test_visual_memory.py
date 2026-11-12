import sys,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(ROOT/"tools/assets"),str(ROOT/"tools")]
from visual_memory import build_catalog
class VisualMemoryTests(unittest.TestCase):
    def test_no_invented_visual_description_or_permission(self):
        item={"name":"Tree_01","selector":[{"index":1,"name":"Tree_01","class":"Model"}],"bounds":[1,2,3],"counts":{"MeshPart":1},"visualComponents":[{"name":"Canopy","meshId":"rbxassetid://123","textureId":"","tint":[1,0,0]}],"technicalCandidate":True,"parts":1,"meshes":1,"pbr":1,"scripts":0}
        report={"assetId":"123","universeId":"1","placeId":"2","loadedVersion":1,"pack":{"totalModels":1,"inventoryTruncated":False,"candidates":[item]}}
        m=build_catalog(report)["models"][0]
        self.assertIsNone(m["visual"]["description"])
        self.assertIsNone(m["visual"]["observed"]["foliageColor"])
        self.assertEqual(m["securityStatus"],"not_approved")
        self.assertEqual(m["components"][0]["meshAssetId"],"123")
        item["visualComponents"][0]["tint"]=[0,1,0]
        self.assertNotEqual(m["modelKey"],build_catalog(report)["models"][0]["modelKey"])
