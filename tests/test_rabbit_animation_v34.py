"""Fail closed on upright vibrating hops, disconnected paws and fake scratch."""
from __future__ import annotations
import json,math,subprocess,sys,tempfile,unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'asset-library/candidates/rabbit-v3-cartoon-v2-mobile-lod0/asset.glb'
AUTHOR=ROOT/'tools/creature_factory/rabbit_animation_author_v34.py'

class RabbitV34(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.tmp=tempfile.TemporaryDirectory()
  subprocess.run([sys.executable,str(AUTHOR),str(SOURCE),cls.tmp.name],
                 cwd=ROOT,check=True,timeout=160)
  cls.man=json.loads((Path(cls.tmp.name)/'manifest.json').read_text())
 @classmethod
 def tearDownClass(cls):cls.tmp.cleanup()
 def test_review_only(self):
  self.assertEqual(self.man['stage'],'visual_review_required_no_roblox_upload_or_place_write')
  self.assertEqual(set(self.man['clips']),{'Idle','Walk','Run','ScratchEar'})
 def test_gait_nonupright_and_paw_grounded(self):
  for clip in ('Idle','Walk','Run'):
   samples=self.man['clips'][clip]['samples']
   # A real jump rises substantially: height gate applies at rest, not apex.
   self.assertLess(samples[0]['head'][1],1.30,clip)
   self.assertLess(max(p['head'][1] for p in samples),2.70,clip)
   self.assertLess(samples[0]['head'][2],-.5,clip)
   self.assertLess(samples[0]['forepaw'][1],.38,clip)
   self.assertLess(samples[0]['hindpaw'][1],.36,clip)
 def test_hop_full_body_not_vibration(self):
  walk=self.man['clips']['Walk']['samples']
  run=self.man['clips']['Run']['samples']
  w=max(r['root_y'] for r in walk)-min(r['root_y'] for r in walk)
  r=max(x['root_y'] for x in run)-min(x['root_y'] for x in run)
  self.assertGreater(w,.50)
  self.assertGreater(r,1.)
  self.assertGreater(r,w*1.6)
  self.assertGreater(max(x['forepaw'][1] for x in run)-min(x['forepaw'][1] for x in run),.65)
  self.assertGreater(max(x['hindpaw'][1] for x in run)-min(x['hindpaw'][1] for x in run),.65)
 def test_scratch_front_paw_makes_contact(self):
  clip=self.man['clips']['ScratchEar']
  for r in clip['blocking']:
   if r['raised']==1:
    self.assertLess(r['forepaw_to_ear_distance'],.46,r)
  for t in (.33,.54,.74):
   row=min(clip['samples'],key=lambda x:abs(x['t']-t))
   d=math.dist(row['forepaw'],row['ear'])
   self.assertLess(d,.50,(t,d))
  self.assertFalse(clip['loop'])
 def test_clip_xml_tracks_all_native_bones(self):
  import xml.etree.ElementTree as ET
  for clip,report in self.man['clips'].items():
   root=ET.parse(Path(self.tmp.name)/report['file']).getroot()
   frames=root.findall('.//Item[@class="Keyframe"]')
   self.assertEqual(len(frames),report['frames'])
   self.assertTrue(all(len(x.findall('.//Item[@class="Pose"]'))==20 for x in frames),clip)
   self.assertGreater(report['maxMotionComponent'],.01)

if __name__=='__main__':unittest.main()
