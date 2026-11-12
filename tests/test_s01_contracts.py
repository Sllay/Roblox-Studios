import sys,unittest,tempfile,json
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"tools"))
from cloud_tasks import run_task,resume_task,validate_path
from scene_sync import compose_task,compile_task
from workspace import WorkspaceError
P="universes/1/places/2/versions/14/luau-execution-sessions/a/tasks/b"
class S01Tests(unittest.TestCase):
    def test_ambiguous_post_no_replay(self):
        with tempfile.TemporaryDirectory() as d:
            path=Path(d)/"task.json"
            with patch("cloud_tasks.request_api",side_effect=WorkspaceError("network")) as api:
                with self.assertRaises(WorkspaceError):run_task("1","2","key","return 1",journal=path)
                with self.assertRaises(WorkspaceError):run_task("1","2","key","return 1",journal=path)
                self.assertEqual(api.call_count,1)
                self.assertEqual(json.loads(path.read_text())["status"],"submission_unknown")
    def test_poll_resume_get_only(self):
        complete={"state":"COMPLETE","path":P,"output":{"results":[json.dumps({"universeId":"1","placeId":"2"})]}}
        with patch("cloud_tasks.request_api",return_value=complete) as api:
            self.assertEqual(resume_task("1","2","key",P)["loadedVersion"],14)
            api.assert_called_once_with(P,"key")
        with patch("cloud_tasks.request_api",return_value={**complete,"path":P.replace("/tasks/b","/tasks/c")}):
            with self.assertRaises(WorkspaceError):resume_task("1","2","key",P)
    def test_wrong_target(self):
        with self.assertRaises(WorkspaceError):validate_path(P,"1","3")
    def test_compile_fail_closed(self):
        with patch("scene_sync.shutil.which",return_value=None):
            with self.assertRaises(WorkspaceError):compile_task("return 1")
    def test_composition(self):
        t={"universeId":"1","placeId":"2","game":"mapa-principal","place":"main","environment":"staging"}
        source=compose_task(t,"do return syncResult({ok=true}) end")
        self.assertNotIn("__RS_CONFIG__",source)
        self.assertNotIn("__RS_SYNC_DISPATCH__",source)
        self.assertIn("local function syncResult",source)
