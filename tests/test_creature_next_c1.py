import json,tempfile,unittest
from pathlib import Path
from dataclasses import asdict
from PIL import Image,ImageDraw
from tools.creature_factory.next.contracts import *
from tools.creature_factory.next.dag import *
class C1Tests(unittest.TestCase):
    def setUp(self):
        self.t=tempfile.TemporaryDirectory();self.addCleanup(self.t.cleanup);self.root=Path(self.t.name);self.src=self.root/"source";self.src.mkdir();self.job=self.root/"job"
        self.image=self.src/"sheet.png";im=Image.new("RGBA",(80,20))
        for i in range(7):ImageDraw.Draw(im).rectangle((i*10+2,3,i*10+7,16),fill=(1,2,3,255))
        im.save(self.image);self.man=self.src/"manifest.json";self.make_manifest()
    def make_manifest(self):
        self.m=AssetManifest("test","creature",[ReferenceView(v,"sheet.png",sha256(self.image),[i*10,0,10,20],CameraCalibration("unknown")) for i,v in enumerate(VIEWS)],rig_required=True)
        write_json(self.man,asdict(self.m))
    def fake(self,m,source,out,cfg):
        write_json(out/"result.json",{"fixture_only":True,"config":cfg});return {}
    def runjob(self,cfg=None,resume=False,runners=None):
        return build(self.man,self.job,cfg,resume=resume,runners=runners or {s.name:self.fake for s in STAGES})
    def attempts(self,s):return {k:v["attempt"] for k,v in s["stages"].items()}
    def test_contract(self):self.assertEqual(validate_manifest(AssetManifest.read(self.man),self.src)["status"],"structurally_valid")
    def test_overlap(self):
        v=asdict(self.m);v["views"][1]["crop"]=v["views"][0]["crop"];write_json(self.man,v)
        with self.assertRaises(ContractError):AssetManifest.read(self.man)
    def test_unknown_camera(self):
        with self.assertRaises(ContractError):CameraCalibration("unknown",ortho_scale=1)
    def test_nan(self):
        with self.assertRaises(ContractError):CameraCalibration("known","orthographic",confidence=float("nan"))
    def test_missing_and_legacy(self):
        v=asdict(self.m);v["views"].pop();write_json(self.man,v)
        with self.assertRaises(ContractError):AssetManifest.read(self.man)
        v["legacy"]=True;write_json(self.man,v);self.assertEqual(len(validate_manifest(AssetManifest.read(self.man),self.src)["missing_views"]),1)
    def test_reference_bytes(self):
        a=self.attempts(self.runjob());im=Image.open(self.image);im.putpixel((3,4),(99,1,1,255));im.save(self.image);self.make_manifest()
        b=self.attempts(self.runjob(resume=True));self.assertTrue(all(a[k]!=b[k] for k in a))
    def test_resume_and_uv_material(self):
        a=self.attempts(self.runjob());b=self.attempts(self.runjob(resume=True));self.assertEqual(a,b)
        c=self.attempts(self.runjob({"uv_ready":{"resolution":4096}},True))
        for k in ("intake","master_ready","optimized","rig_ready"):self.assertEqual(b[k],c[k])
        for k in ("uv_ready","materials_ready","packaged","review_ready"):self.assertNotEqual(b[k],c[k])
        d=self.attempts(self.runjob({"uv_ready":{"resolution":4096},"materials_ready":{"palette":"brown"}},True))
        self.assertEqual(c["uv_ready"],d["uv_ready"]);self.assertEqual(c["rig_ready"],d["rig_ready"]);self.assertNotEqual(c["materials_ready"],d["materials_ready"])
    def test_corruption(self):
        s=self.runjob();p=next(iter(s["stages"]["uv_ready"]["outputs"]));(self.job/p).write_text("tampered")
        self.assertEqual(validate_job(self.job)["status"],"invalid")
        n=self.runjob(resume=True);self.assertEqual(s["stages"]["optimized"]["attempt"],n["stages"]["optimized"]["attempt"]);self.assertNotEqual(s["stages"]["uv_ready"]["attempt"],n["stages"]["uv_ready"]["attempt"])
    def test_interrupted(self):
        def crash(m,source,out,cfg): (out/"partial").write_text("partial");raise KeyboardInterrupt()
        with self.assertRaises(KeyboardInterrupt):self.runjob(runners={**{s.name:self.fake for s in STAGES},"uv_ready":crash})
        s=read_state(self.job);self.assertEqual(s["stages"]["uv_ready"]["state"],"running")
        n=self.runjob(resume=True);self.assertEqual(n["status"],"review_ready");self.assertNotEqual(s["stages"]["uv_ready"]["attempt"],n["stages"]["uv_ready"]["attempt"])
    def test_failure_recovery(self):
        def fail(*a):raise ValueError("deterministic")
        s=self.runjob(runners={**{s.name:self.fake for s in STAGES},"uv_ready":fail});self.assertEqual(s["stages"]["uv_ready"]["state"],"failed");self.assertEqual(s["stages"]["packaged"]["state"],"blocked")
        self.assertEqual(self.runjob(resume=True)["status"],"review_ready")
    def test_transient_retry(self):
        count=[]
        def transient(*a):
            count.append(1)
            if len(count)==1:raise TransientError("retry")
            return self.fake(*a)
        self.runjob({"uv_ready":{"transient_retries":1}},runners={**{s.name:self.fake for s in STAGES},"uv_ready":transient});self.assertEqual(len(count),2)
    def test_locks(self):
        with lock(self.job):
            with self.assertRaises(JobError):
                with lock(self.job):pass
            with lock(self.root/"other"):pass
    def test_traversal(self):
        with self.assertRaises(ContractError):path_inside(self.src,"../outside")
        (self.src/"escape").symlink_to(self.root)
        with self.assertRaises(ContractError):path_inside(self.src,"escape/job")
    def test_default_blocks(self):
        s=build(self.man,self.job);self.assertEqual(s["stages"]["reference_ready"]["state"],"succeeded");self.assertEqual(s["stages"]["evidence_ready"]["state"],"blocked");self.assertEqual(s["status"],"incomplete")
    def test_atomic_write(self):
        p=self.root/"atomic.json";write_json(p,{"ok":True})
        with self.assertRaises(ValueError):write_json(p,{"bad":float("nan")})
        self.assertEqual(json.loads(p.read_text()),{"ok":True})
