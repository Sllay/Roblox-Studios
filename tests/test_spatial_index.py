import base64,struct,sys,unittest,math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"tools"))
from spatial_index import SurfaceIndex,Occupancy,place_candidates
def tile(id,x,wet=False):
    rows=[(float(x+i*4+2)/2,1,int(wet and i==0 and j==2)) for j in range(8) for i in range(8)]
    return {"id":id,"bounds":[x,-32,0,x+32,112,32],"nx":8,"nz":8,"samples":base64.b64encode(b"".join(struct.pack("<fHB",*r) for r in rows)).decode()}
class SpatialTests(unittest.TestCase):
    def test_cross_seam_and_normal(self):
        s=SurfaceIndex([tile("a",0),tile("b",32)],{"1":"Grass"})
        self.assertEqual(s.height(32,14),16)
        v=s.support(32,14,2)
        self.assertAlmostEqual(v["slope"],math.degrees(math.atan(.5)))
        self.assertAlmostEqual(sum(x*x for x in v["normal"]),1)
        self.assertTrue(s.dry(32,14,2))
        self.assertFalse(s.dry(0,14,1))
    def test_water_and_occupancy(self):
        s=SurfaceIndex([tile("a",0),tile("b",32,True)],{"1":"Grass"})
        self.assertEqual(s.water_clearance(30,10,8),2)
        self.assertFalse(s.dry(32,10,1))
        o=Occupancy([{"id":"a","x":31,"z":10,"radius":2}])
        self.assertTrue(o.blocked(33,10,1))
        self.assertFalse(o.blocked(33,10,1,"a"))
        o.remove("a");self.assertFalse(o.blocked(33,10,1))
    def test_determinism(self):
        s=SurfaceIndex([tile("a",0),tile("b",32)],{"1":"Grass"})
        r={"materials":["Grass"],"radius":.5,"footprint":.5,"supportRadius":1,"waterClearance":2,"maxSlope":35,"maxRelief":2,"spacing":1,"altitudePercentile":None}
        a=place_candidates(s,Occupancy(),r,7,3,"stone")
        self.assertEqual(a,place_candidates(s,Occupancy(),r,7,3,"stone"))
        self.assertEqual(len(a[0]),6)
