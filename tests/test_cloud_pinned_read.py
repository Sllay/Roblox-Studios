import json,sys,unittest
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"tools"))
from cloud_tasks import run_task
from workspace import WorkspaceError
class PinnedReadTests(unittest.TestCase):
    def test_pin(self):
        path="universes/1/places/2/versions/14/luau-execution-sessions/a/tasks/b"
        complete={"state":"COMPLETE","path":path,"output":{"results":[json.dumps({"universeId":"1","placeId":"2"})]}}
        with patch("cloud_tasks.request_api",side_effect=[{"path":path},complete]) as api:
            self.assertEqual(run_task("1","2","key","return 1",read_version=14)["loadedVersion"],14)
            self.assertEqual(api.call_args_list[0].args[0],"universes/1/places/2/versions/14/luau-execution-session-tasks")
    def test_mismatch(self):
        with patch("cloud_tasks.request_api",return_value={"path":"universes/1/places/2/versions/15/luau-execution-sessions/a/tasks/b"}):
            with self.assertRaises(WorkspaceError):run_task("1","2","key","return 1",read_version=14)
        with self.assertRaises(WorkspaceError):run_task("1","2","key","return 1",read_version=True)
