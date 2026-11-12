import sys,unittest,base64,struct
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"tools"))
from terrain_atlas import decode,percentile
from workspace import WorkspaceError
class TerrainAtlasTests(unittest.TestCase):
    def test_decode_and_percentile(self):
        data=struct.pack("<hHB",-12,1280,1)+struct.pack("<hHB",235,1280,0)
        self.assertEqual(decode({"nx":2,"nz":1,"samples":base64.b64encode(data).decode()}),[(-1.2,1280,True),(23.5,1280,False)])
        self.assertEqual(percentile([1,2,3,4,5],.8),4)
        with self.assertRaises(WorkspaceError):decode({"nx":3,"nz":1,"samples":base64.b64encode(data).decode()})
