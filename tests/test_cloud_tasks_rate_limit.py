import sys,unittest
from pathlib import Path
from unittest.mock import patch
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"tools"))
import cloud_tasks as c
class RateLimitTests(unittest.TestCase):
    def test_get_retry_only(self):
        with patch.object(c,"request_api",side_effect=[c.WorkspaceError("Roblox API HTTP 429"),{"state":"COMPLETE"}]) as request,patch.object(c.time,"sleep") as sleep:
            self.assertEqual(c.poll_task("task","key"),{"state":"COMPLETE"})
            self.assertEqual(request.call_count,2)
            sleep.assert_called_once_with(8)
    def test_post_not_retried(self):
        with patch.object(c,"request_api",side_effect=c.WorkspaceError("Roblox API HTTP 429")) as request:
            with self.assertRaises(c.WorkspaceError):c.run_task("1","2","key","source")
            request.assert_called_once()
