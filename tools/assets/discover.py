#!/usr/bin/env python3
"""Read-only Creator Store discovery: JSON, offline HTML gallery, and PNG contact sheet.

Reads Roblox's official Toolbox Service and Thumbnails APIs. No Place changes.
All assets remain unapproved until human review and separate safety inspection.
"""
from __future__ import annotations

import argparse
import html
import io
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
SEARCH_API = "https://apis.roblox.com/toolbox-service/v2/assets:search"
THUMB_API = "https://thumbnails.roblox.com/v1/assets"
SAFE_ID = re.compile(r"^[1-9][0-9]*$")
SLUG = re.compile(r"^[a-z][a-z0-9-]*$")
MAX_ITEMS = 24


class DiscoveryError(Exception):
    pass


def check_thumbnail_url(value: str) -> bool:
    """Prevent arbitrary URL downloads: only HTTPS Roblox CDN thumbnail hosts."""
    if not value or len(value) > 1200:
        return False
    parsed = urllib.parse.urlsplit(value)
    host = (parsed.hostname or "").lower()
    return parsed.scheme == "https" and not parsed.username and not parsed.password and (
        host == "rbxcdn.com" or host.endswith(".rbxcdn.com") or host == "roblox.com"
        or host.endswith(".roblox.com")
    )


def fetch_json(url: str, *, api_key: str = "") -> dict:
    headers = {"Accept": "application/json", "User-Agent": "Roblox-Studios/AssetDiscovery"}
    if api_key:
        headers["x-api-key"] = api_key
    req = urllib.request.Request(url, headers=headers)
    for attempt in range(3):
        try:
            with urllib.request.urlopen(req, timeout=25) as response:
                result = json.load(response)
            if not isinstance(result, dict):
                raise DiscoveryError("Unexpected Roblox JSON response")
            return result
        except urllib.error.HTTPError as exc:
            if exc.code in (429, 502, 503) and attempt < 2:
                time.sleep(2 ** (attempt + 1))
                continue
            detail = exc.read(300).decode("utf-8", errors="replace")
            raise DiscoveryError(f"Roblox API HTTP {exc.code}: {detail}. Rate limits or missing creator-store-product:read permission may apply") from None
        except (urllib.error.URLError, ValueError, TimeoutError) as exc:
            raise DiscoveryError(f"Roblox API request failed: {exc}") from exc
    raise DiscoveryError("Roblox API request failed after bounded retries")


def search_models(query: str, count: int, key: str = "") -> list[dict]:
    if not query.strip() or len(query) > 100:
        raise DiscoveryError("Search term must have 1-100 characters")
    if not 1 <= count <= MAX_ITEMS:
        raise DiscoveryError(f"Requested count must be 1-{MAX_ITEMS}")
    params = urllib.parse.urlencode({
        "searchCategoryType": "Model", "query": query.strip(),
        "maxPageSize": str(count), "searchView": "Core",
        "includeOnlyVerifiedCreators": "false"
    })
    response = fetch_json(SEARCH_API + "?" + params, api_key=key)
    items = response.get("creatorStoreAssets")
    if not isinstance(items, list):
        raise DiscoveryError("Creator Store response lacks creatorStoreAssets list")
    normalized = []
    seen = set()
    for raw in items:
        if not isinstance(raw, dict):
            continue
        asset = raw.get("asset") or {}
        creator = raw.get("creator") or {}
        product = raw.get("creatorStoreProduct") or {}
        asset_id = str(asset.get("id", ""))
        if not SAFE_ID.fullmatch(asset_id) or asset_id in seen:
            continue
        seen.add(asset_id)
        price = product.get("purchasePrice")
        normalized.append({
            "id": asset_id, "name": str(asset.get("name") or "Untitled")[:160],
            "description": str(asset.get("description") or "")[:1000],
            "creator": str(creator.get("name") or "Unknown")[:100],
            "verifiedCreator": creator.get("verified") is True,
            "creatorId": str(creator.get("userId") or creator.get("groupId") or ""),
            "categoryPath": str(asset.get("categoryPath") or ""),
            "updatedAt": str(asset.get("updateTime") or ""),
            "price": price if isinstance(price, dict) else None,
            "purchasable": product.get("purchasable"),
            "url": f"https://create.roblox.com/store/asset/{asset_id}",
            "thumbnail": None, "localThumbnail": None,
            "status": "candidate_unreviewed",
        })
        if len(normalized) >= count:
            break
    if not normalized:
        raise DiscoveryError("Creator Store returned no eligible Model candidates")
    return normalized


def thumbnails(ids: list[str]) -> dict[str, str]:
    if not ids or any(not SAFE_ID.fullmatch(i) for i in ids):
        raise DiscoveryError("Thumbnail IDs must be positive decimal asset IDs")
    params = urllib.parse.urlencode({
        "assetIds": ",".join(ids), "size": "420x420",
        "format": "Png", "isCircular": "false"
    })
    payload = fetch_json(THUMB_API + "?" + params)
    results = {}
    for item in payload.get("data", []):
        if not isinstance(item, dict):
            continue
        asset_id, value = str(item.get("targetId", "")), item.get("imageUrl")
        if asset_id in ids and isinstance(value, str) and check_thumbnail_url(value):
            results[asset_id] = value
    return results


def download_thumbnail(url: str) -> Image.Image | None:
    if not check_thumbnail_url(url):
        return None
    req = urllib.request.Request(url, headers={"User-Agent": "Roblox-Studios/AssetDiscovery"})
    try:
        with urllib.request.urlopen(req, timeout=18) as resp:
            final_url = resp.geturl()
            if not check_thumbnail_url(final_url):
                raise DiscoveryError("Thumbnail redirected outside official Roblox hosts")
            data = resp.read(2_000_001)
        if len(data) > 2_000_000:
            raise DiscoveryError("Thumbnail exceeds 2 MB")
        image = Image.open(io.BytesIO(data))
        image.load()
        if image.width > 2048 or image.height > 2048:
            raise DiscoveryError("Thumbnail dimensions exceed safe bounds")
        return image.convert("RGB")
    except (urllib.error.URLError, OSError, ValueError) as exc:
        print(f"WARNING: thumbnail failed: {exc}", file=sys.stderr)
        return None


def text_trim(draw: ImageDraw.ImageDraw, value: str, width: int, font) -> str:
    value = " ".join(str(value).split())
    while value and draw.textbbox((0, 0), value, font=font)[2] > width:
        value = value[:-2].rstrip() + "…"
    return value


def render(outputs: Path, items: list[dict], *, game: str, query: str, biome: str) -> None:
    outputs.mkdir(parents=True, exist_ok=True)
    thumbs = outputs / "thumbs"
    thumbs.mkdir(exist_ok=True)
    thumb_urls = thumbnails([x["id"] for x in items])
    images: dict[str, Image.Image] = {}
    for item in items:
        url = thumb_urls.get(item["id"])
        if not url:
            continue
        image = download_thumbnail(url)
        if image is None:
            continue
        image.thumbnail((420, 420))
        path = thumbs / (item["id"] + ".png")
        image.save(path, "PNG", optimize=True)
        item["thumbnail"] = url
        item["localThumbnail"] = "thumbs/" + item["id"] + ".png"
        images[item["id"]] = image

    catalog = {
        "schemaVersion": 1, "source": "Roblox Creator Store", "game": game,
        "query": query, "biomeHint": biome, "automaticApproval": False,
        "candidates": items,
    }
    (outputs / "candidates.json").write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    cols, w, h = 4, 256, 294
    rows = (len(items) + cols - 1) // cols
    board = Image.new("RGB", (cols * w, rows * h + 68), "#eaf0f5")
    draw = ImageDraw.Draw(board)
    font = ImageFont.load_default()
    draw.rectangle((0, 0, cols * w, 65), fill="#172638")
    draw.text((17, 14), f"Creator Store | {query[:55]} | {game}", fill="white", font=font)
    draw.text((17, 34), f"Biome hint: {biome[:60] or 'none'} | Candidates only - NOT vetted", fill="#b3c7df", font=font)
    for idx, asset in enumerate(items):
        x, y = (idx % cols) * w, 68 + (idx // cols) * h
        draw.rectangle((x + 6, y + 6, x + w - 7, y + h - 7), fill="white", outline="#c7d0da")
        img = images.get(asset["id"])
        if img:
            img = img.copy()
            img.thumbnail((226, 213))
            board.paste(img, (x + (w - img.width) // 2, y + 14 + (212 - img.height) // 2))
        else:
            draw.rectangle((x + 15, y + 17, x + 241, y + 226), fill="#e5e9ed")
            draw.text((x + 55, y + 109), "Preview unavailable", fill="#687684", font=font)
        draw.text((x + 12, y + 238), text_trim(draw, asset["name"], 228, font), fill="#152438", font=font)
        draw.text((x + 12, y + 256), f"ID: {asset['id']}", fill="#566473", font=font)
        draw.text((x + 12, y + 273), text_trim(draw, asset["creator"], 228, font), fill="#566473", font=font)
    board.save(outputs / "contact-sheet.png", optimize=True)

    cards = []
    for asset in items:
        name, creator = html.escape(asset["name"]), html.escape(asset["creator"])
        link = html.escape(asset["url"], quote=True)
        id_text = html.escape(asset["id"])
        pic = (f'<img loading="lazy" src="{html.escape(asset["localThumbnail"], quote=True)}" alt="{name}">'
               if asset["localThumbnail"] else '<div class="missing">Preview unavailable</div>')
        cards.append(f'<article class="card"><a href="{link}" target="_blank" rel="noopener noreferrer">{pic}<strong>{name}</strong></a>'
                     f'<span>Creator: {creator}</span><code>Asset ID: {id_text}</code><small>NOT INSPECTED / NOT APPROVED</small></article>')
    page = f"""<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Asset Gallery</title>
<style>body{{font:15px system-ui;background:#edf1f7;color:#182a3a;margin:0}}header{{background:#172638;color:white;padding:25px}}main{{padding:18px}}.grid{{display:grid;grid-template-columns:repeat(auto-fit,minmax(210px,1fr));gap:16px}}.card{{display:flex;flex-direction:column;gap:8px;padding:12px;background:white;border:1px solid #cbd6e0;border-radius:13px;overflow:hidden}}.card img,.missing{{width:100%;aspect-ratio:1;object-fit:contain;background:#f1f5f8;border-radius:7px}}a{{display:flex;flex-direction:column;gap:8px;color:#134b87;text-decoration:none}}code,small,span{{color:#55677b}}small{{font-weight:bold;color:#9c482f}}.missing{{display:grid;place-items:center;color:#6c7f94}}</style></head>
<body><header><h1>Creator Store | {html.escape(query)}</h1><p>Game: {html.escape(game)} · Biome hint: {html.escape(biome or "none")} · Review candidates only; no automatic import</p></header><main><div class="grid">{"".join(cards)}</div></main></body></html>"""
    (outputs / "gallery.html").write_text(page, encoding="utf-8")
    print(f"CREATED {len(items)} candidates; {len(images)} thumbnails; files in {outputs}")


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--game", required=True)
    p.add_argument("--query", required=True)
    p.add_argument("--biome", default="")
    p.add_argument("--count", type=int, default=16)
    p.add_argument("--output", type=Path, default=ROOT / "dist" / "asset-discovery")
    args = p.parse_args(argv)
    try:
        if not SLUG.fullmatch(args.game) or args.game.startswith("_") or not (ROOT / "games" / "maps" / args.game / "game.manifest.json").is_file():
            raise DiscoveryError(f"Unknown or unsafe game slug: {args.game}")
        if len(args.biome) > 80:
            raise DiscoveryError("Biome hint must contain at most 80 characters")
        key = os.environ.get("ROBLOX_CREATOR_STORE_API_KEY", "")
        assets = search_models(args.query, args.count, key)
        render(args.output, assets, game=args.game, query=args.query, biome=args.biome)
        return 0
    except (DiscoveryError, OSError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
