"""V35 rabbit gait must pass anatomically meaningful native-skeleton tests.

Never certify an animation only because Roblox can load it.
"""
from __future__ import annotations
import json,math,subprocess,sys,tempfile,unittest,xml.etree.ElementTree as ET
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'asset-library/candidates/rabbit-v3-cartoon-v2-mobile-lod0/asset.glb'
AUTHOR=ROOT/'tools/creature_factory/rabbit_animation_author_v35.py'

class RabbitV35(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.tmp=tempfile.TemporaryDirectory()
  subprocess.run([sys.executable,str(AUTHOR),str(SOURCE),cls.tmp.name],
                 cwd=ROOT,check=True,timeout=190)
  cls.man=json.loads((Path(cls.tmp.name)/'manifest.json').read_text())
 @classmethod
 def tearDownClass(cls):cls.tmp.cleanup()
 def test_review_only(self):
  self.assertEqual(self.man['stage'],'v35_visual_review_required_no_roblox_upload_or_place_write')
  self.assertEqual(set(self.man['clips']),{'Idle','Walk','Run','ScratchEar'})
 def test_substantial_hops_with_landings(self):
  w=self.man['clips']['Walk'];r=self.man['clips']['Run']
  for name,clip in [('Walk',w),('Run',r)]:
   rows=clip['samples']; heights=[q['root_y'] for q in rows]
   self.assertAlmostEqual(heights[0],heights[-1],delta=.001,msg=name)
   self.assertGreater(max(heights)-min(heights),.60 if name=='Walk' else 1.20)
   phase_land=.72 if name=='Walk' else .79
   landed=min(rows,key=lambda z:abs(z['t']-phase_land))
   self.assertLess(landed['forepaw'][1],.35,name)
   self.assertGreater(landed['hindpaw'][1]-landed['forepaw'][1],.16,name)
   # Not just root jitter: hind and front foot trajectories diverge.
   self.assertGreater(max(z['forepaw'][2] for z in rows)-min(z['forepaw'][2] for z in rows),.25,name)
   self.assertGreater(max(z['hindpaw'][1] for z in rows)-min(z['hindpaw'][1] for z in rows),.54,name)
  self.assertLess(w['duration'] if False else w['samples'][0]['head'][1],1.3)
 def test_hindpaw_ear_scratch_not_fake_forepaw(self):
  sc=self.man['clips']['ScratchEar']
  self.assertFalse(sc['loop'])
  self.assertGreater(sc['duration'],2)
  raised=[x for x in sc['blocking'] if x['raised']==1]
  self.assertGreaterEqual(len(raised),4)
  self.assertTrue(all(x['hindpaw_to_ear_base_distance']<.20 for x in raised))
  self.assertTrue(all(abs(x['hip_pitch'])<=1.501 and abs(x['hip_roll'])<.75 for x in raised))
  first=sc['samples'][0]
  peak=min(sc['samples'],key=lambda z:abs(z['t']-.52))
  self.assertGreater(peak['hindpaw'][1]-first['hindpaw'][1],.30)
  self.assertLess(abs(peak['forepaw_right'][1]-first['forepaw_right'][1]),.38)
 def test_cycle_closure_and_native_bone_count(self):
  for name,clip in self.man['clips'].items():
   x=ET.parse(Path(self.tmp.name)/clip['file']).getroot()
   frames=x.findall('.//Item[@class="Keyframe"]')
   self.assertEqual(len(frames),clip['frames'],name)
   self.assertTrue(all(len(q.findall('.//Item[@class="Pose"]'))==20 for q in frames),name)
   self.assertGreater(clip['maxMotionComponent'],.01,name)
   if clip['loop']:
    a,b=clip['samples'][0],clip['samples'][-1]
    for bone in ('forepaw','hindpaw','head'):
     self.assertLess(math.dist(a[bone],b[bone]),.005,(name,bone))

if __name__=='__main__':unittest.main()
