import sys,unittest,struct,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"tools/assets"))
from author_pine_rig import build
class PineRigTests(unittest.TestCase):
    def test_glb(self):
        b,r=build();self.assertEqual(b,build()[0]);self.assertEqual(struct.unpack_from("<4sII",b),(b"glTF",2,len(b)))
        n,k=struct.unpack_from("<I4s",b,12);self.assertEqual(k,b"JSON");d=json.loads(b[20:20+n])
        self.assertEqual(len(d["skins"][0]["joints"]),r["bones"])
        self.assertGreater(r["weightedVertices"],0);self.assertGreater(r["fixedVertices"],0)
        self.assertLessEqual(r["bones"],32)
