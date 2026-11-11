#!/usr/bin/env python3
"""Non-destructive Roblox Luau Open Cloud smoke test for an existing Place.

Creates or updates only the marker-owned smoke test model and two script
instances; NEVER uploads a new .rbxlx over the existing Place.
"""
from __future__ import annotations
import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from deploy import load_all, resolve, WorkspaceError

ROOT = Path(__file__).resolve().parents[1]
BASE = "https://apis.roblox.com/cloud/v2"
OWNER = "RobloxStudiosCloudSmokeV1"
GAME_NAME = "mapa-principal"
PLACE_NAME = "main"
ENV_NAME = "production"
SRC = ROOT / "games" / "maps" / GAME_NAME / "game" / "places" / PLACE_NAME / "src"
SERVER_FILE = SRC / "ServerScriptService" / "CloudFloatController.server.luau"
CLIENT_FILE = SRC / "StarterPlayer" / "StarterPlayerScripts" / "CloudFloatClient.client.luau"
CLOUD_PREFIX = "RobloxStudiosSmoke"
RETRY_LIMIT = 30


def long_literal(source):
    """Embed trusted Luau source text without escaping or truncating its contents."""
    for depth in range(1, 16):
        equal = "=" * depth
        closing = "]" + equal + "]"
        if closing not in source:
            return "[" + equal + "[" + source + closing
    raise WorkspaceError("Unable to safely encode Luau source text")


def identity_script(universe, place):
    return f"""
assert(tostring(game.GameId) == "{universe}", "Universe ID mismatch")
assert(tostring(game.PlaceId) == "{place}", "Place ID mismatch")
local Workspace = game:GetService("Workspace")
local SSS = game:GetService("ServerScriptService")
local SPS = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
for _, pair in {{
    {{ Workspace, "RobloxStudiosSmoke" }},
    {{ SSS, "CloudFloatController" }},
    {{ SPS, "CloudFloatClient" }},
}} do
    local object = pair[1]:FindFirstChild(pair[2])
    if object then
        assert(object:GetAttribute("SmokeOwner") == "{OWNER}",
            "Name collision with non-smoke object: " .. pair[2])
    end
end
return "IDENTITY_OK"
"""


def apply_script(universe, place, server, client):
    head = identity_script(universe, place)
    server_lua = long_literal(server)
    client_lua = long_literal(client)
    return head[:head.rfind('return "IDENTITY_OK"')] + f"""
local AssetService = game:GetService("AssetService")
local Workspace = game:GetService("Workspace")
local SSS = game:GetService("ServerScriptService")
local SPS = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")

local folder = Workspace:FindFirstChild("{CLOUD_PREFIX}")
if not folder then
    folder = Instance.new("Model")
    folder.Name = "{CLOUD_PREFIX}"
    folder:SetAttribute("SmokeOwner", "{OWNER}")
    folder.Parent = Workspace
end
assert(folder:IsA("Model"), "Smoke folder has wrong class")

local platform = folder:FindFirstChild("FloatingPlatform")
if not platform then
    platform = Instance.new("Part")
    platform.Name = "FloatingPlatform"
    platform.Parent = folder
end
assert(platform:IsA("Part"), "Smoke platform name collision")
local spawn = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
local anchor = if spawn then spawn.Position + Vector3.new(18, 7, 0) else Vector3.new(0, 10, -20)
platform.Size = Vector3.new(12, 1, 12)
platform.Position = anchor
platform.Color = Color3.fromRGB(26, 166, 255)
platform.Material = Enum.Material.Neon
platform.CanCollide = true
platform.Anchored = true
platform:SetAttribute("SmokeOwner", "{OWNER}")

local serverScript = SSS:FindFirstChild("CloudFloatController")
if not serverScript then
    serverScript = Instance.new("Script")
    serverScript.Name = "CloudFloatController"
    serverScript.Enabled = false
    serverScript:SetAttribute("SmokeOwner", "{OWNER}")
    serverScript.Parent = SSS
end
assert(serverScript:IsA("Script"), "ServerScript name collision")
serverScript.Source = {server_lua}
serverScript.Enabled = true

local localScript = SPS:FindFirstChild("CloudFloatClient")
if not localScript then
    localScript = Instance.new("LocalScript")
    localScript.Name = "CloudFloatClient"
    localScript.Enabled = false
    localScript:SetAttribute("SmokeOwner", "{OWNER}")
    localScript.Parent = SPS
end
assert(localScript:IsA("LocalScript"), "LocalScript name collision")
localScript.Source = {client_lua}
localScript.Enabled = true

AssetService:SavePlaceAsync({{SaveWithoutPublish = false}})
print("[RobloxStudiosSmoke] SavePlaceAsync returned")
return "SAVE_CALLED"
"""


def verification_script(universe, place):
    return f"""
assert(tostring(game.GameId) == "{universe}" and tostring(game.PlaceId) == "{place}", "Identity mismatch")
local folder = game:GetService("Workspace"):FindFirstChild("{CLOUD_PREFIX}")
assert(folder and folder:IsA("Model") and folder:GetAttribute("SmokeOwner") == "{OWNER}", "Smoke Model missing")
local part = folder:FindFirstChild("FloatingPlatform")
assert(part and part:IsA("Part") and part.Anchored, "Smoke Part missing")
local server = game:GetService("ServerScriptService"):FindFirstChild("CloudFloatController")
assert(server and server:IsA("Script") and server:GetAttribute("SmokeOwner") == "{OWNER}", "Server Script missing")
local localScript = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):FindFirstChild("CloudFloatClient")
assert(localScript and localScript:IsA("LocalScript") and localScript:GetAttribute("SmokeOwner") == "{OWNER}", "Local Script missing")
assert(string.find(server.Source, "TweenService", 1, true), "Server code missing")
assert(string.find(localScript.Source, "RunService", 1, true), "LocalScript code missing")
return "VERIFIED_PERSISTED"
"""


def request_api(path, key, payload=None):
    if not path.startswith("universes/") or not re.fullmatch(r"[a-zA-Z0-9/_-]+", path) or ".." in path:
        raise WorkspaceError(f"Unexpected Roblox API resource path: {path!r}")
    method = "POST" if payload is not None else "GET"
    data = json.dumps(payload).encode("utf-8") if payload is not None else None
    headers = {"x-api-key": key, "Accept": "application/json"}
    if data is not None:
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(f"{BASE}/{path}", headers=headers, method=method, data=data)
    try:
        with urllib.request.urlopen(req, timeout=45) as resp:
            return json.loads(resp.read(2000000).decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read(1000).decode("utf-8", errors="replace")
        raise WorkspaceError(f"Roblox API HTTP {exc.code}: {detail[:600]}") from None
    except (TimeoutError, urllib.error.URLError, ValueError) as exc:
        raise WorkspaceError(f"Roblox API error: {exc}") from exc


def execute_task(universe, place, key, script):
    resource = f"universes/{universe}/places/{place}/luau-execution-session-tasks"
    created = request_api(resource, key, {"script": script})
    task_path = created.get("path") if isinstance(created, dict) else None
    expected_prefix = f"universes/{universe}/places/{place}/"
    if not isinstance(task_path, str) or not task_path.startswith(expected_prefix):
        raise WorkspaceError(f"Invalid Luau task path returned by Roblox: {task_path!r}")
    print(f"Luau task created: {task_path}", flush=True)
    for attempt in range(RETRY_LIMIT):
        status = request_api(task_path, key)
        state = status.get("state")
        if state == "COMPLETE":
            print(f"Luau task complete: {task_path}", flush=True)
            return status
        if state not in ("PROCESSING", "PENDING", "QUEUED"):
            error = status.get("error", state)
            raise WorkspaceError(f"Luau task failed: {error}")
        if attempt < RETRY_LIMIT - 1:
            time.sleep(3)
    raise WorkspaceError("Luau task timed out; confirm task state manually before retrying")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--execute", action="store_true", help="Make remote write; without this flag do dry-run")
    args = parser.parse_args(argv)
    try:
        games, targets = load_all()
        t = resolve(games, targets, GAME_NAME, PLACE_NAME, ENV_NAME)
        server = SERVER_FILE.read_text(encoding="utf-8")
        client = CLIENT_FILE.read_text(encoding="utf-8")
        if "TweenService" not in server or "RunService" not in client:
            raise WorkspaceError("Smoke test script sources do not satisfy expected contracts")
        preflight = identity_script(t["universeId"], t["placeId"])
        apply = apply_script(t["universeId"], t["placeId"], server, client)
        verify = verification_script(t["universeId"], t["placeId"])
        print(f"Target: {t['game']}/{t['place']} ({t['environment']})"
              f" Universe {t['universeId']} Place {t['placeId']}", flush=True)
        print("Strategy: Luau Execution + SavePlaceAsync; NEVER replace full Place file", flush=True)
        if not args.execute:
            print(f"DRY RUN: {len(apply)} bytes Luau; no API calls made", flush=True)
            return 0
        key = os.environ.get("ROBLOX_OPEN_CLOUD_API_KEY", "").strip()
        if not key:
            raise WorkspaceError("Missing secret ROBLOX_OPEN_CLOUD_API_KEY in GitHub Actions")
        print("1/3 Remote identity and name-collision preflight", flush=True)
        execute_task(t["universeId"], t["placeId"], key, preflight)
        print("2/3 Applying Part, server Script and LocalScript; saving current Place", flush=True)
        execute_task(t["universeId"], t["placeId"], key, apply)
        print("3/3 Loading Place again for persisted state verification", flush=True)
        execute_task(t["universeId"], t["placeId"], key, verify)
        print("SUCCESS: existing Place updated incrementally and saved; all 3 objects verified", flush=True)
        print("Client execution/motion still needs verification in Roblox app.", flush=True)
        return 0
    except (WorkspaceError, OSError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr, flush=True)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
