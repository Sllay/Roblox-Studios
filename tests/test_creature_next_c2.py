import json,math,tempfile,unittest
from pathlib import Path
from PIL import Image,ImageDraw
from tools.creature_factory.next.evidence import analyze_alpha
from tools.creature_factory.next.cameras import project,unproject,estimate_orthographic,AXES
from tools.creature_factory.next.contracts import CameraCalibration,ContractError

class C2Tests(unittest.TestCase):
    def test_mask_preserves_hole_and_small_component(self):
        im=Image.new("RGBA",(32,32));d=ImageDraw.Draw(im)
        d.rectangle((3,3,20,20),fill=(50,70,90,255));d.rectangle((8,8,15,15),fill=(0,0,0,0))
        d.point((28,28),fill=(10,20,30,255));d.point((29,29),fill=(10,20,30,64))
        mask,alpha,r=analyze_alpha(im)
        self.assertEqual(r["components"],3);self.assertEqual(mask.getpixel((10,10)),0)
        self.assertEqual(mask.getpixel((28,28)),255);self.assertEqual(alpha.getpixel((29,29)),64)
        self.assertEqual(r["foreground_pixels"],262)
    def test_empty_and_opaque_fail(self):
        for alpha in (0,255):
            with self.assertRaises(ContractError):analyze_alpha(Image.new("RGBA",(10,10),(0,0,0,alpha)))
    def test_orthographic_roundtrip_nonsquare(self):
        c=CameraCalibration("known","orthographic",[[1,0,0,0],[0,1,0,0],[0,0,1,5],[0,0,0,1]],4,confidence=1)
        p=(1,.5,1);x,y,d=project(c,p,(400,200))
        self.assertEqual((x,y,d),(300,50,4));self.assertEqual(unproject(c,(x,y),d,(400,200)),p)
    def test_perspective_roundtrip(self):
        c=CameraCalibration("known","perspective",[[1,0,0,0],[0,1,0,0],[0,0,1,5],[0,0,0,1]],intrinsics=[[100,2,50],[0,120,40],[0,0,1]],confidence=1)
        p=(1,.5,1);x,y,d=project(c,p,(100,80))
        self.assertAlmostEqual(x,74.75);self.assertAlmostEqual(y,25)
        for a,b in zip(unproject(c,(x,y),d,(100,80)),p):self.assertAlmostEqual(a,b)
    def test_unknown_rejected(self):
        with self.assertRaises(ContractError):project(CameraCalibration("unknown"),(0,0,0),(10,10))
    def test_camera_hypothesis_and_clipped_rejection(self):
        reports={k:{"bbox":[10,10,50 if k in ("front","back") else 30,90],"size":[100,100],"touches_edge":False} for k in ("front","back","left","right")}
        r,h=estimate_orthographic(reports,set(reports))
        self.assertEqual(len(r),4);self.assertEqual(h["normalized_extents"],{"x":.5,"y":.25,"z":1})
        self.assertTrue(all(x["camera"]["status"]=="estimated" and not x["metric_depth_allowed"] for x in r.values()))
        for k in ("left","right"):reports[k]["touches_edge"]=True
        self.assertEqual(estimate_orthographic(reports,set(reports))[0],{})
