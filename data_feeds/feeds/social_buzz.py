"""Reddit /r/all + HackerNews top — pulse social pour viz 'social storm'.

Reddit : /r/all/hot.json — score, num_comments des top posts
HN     : algolia API search_by_date front_page — points, comments

OSC out :
    /data/social_buzz/reddit score_avg comments_avg n
    /data/social_buzz/hn     score_avg comments_avg n
    /data/social_buzz/pulse  combined_score        (event tick toutes ~30s)
"""
from __future__ import annotations

import asyncio
import logging

import httpx

LOG = logging.getLogger("feed.social_buzz")

REDDIT_URL = "https://www.reddit.com/r/all/hot.json?limit=25"
HN_URL = "https://hacker-news.firebaseio.com/v0/topstories.json"
HN_ITEM = "https://hacker-news.firebaseio.com/v0/item/{}.json"


async def _fetch_reddit(cli: httpx.AsyncClient) -> tuple[float, float, int]:
    r = await cli.get(REDDIT_URL,
                      headers={"User-Agent": "av-live-data-feeds/1.0"})
    r.raise_for_status()
    posts = r.json().get("data", {}).get("children", [])
    if not posts:
        return 0.0, 0.0, 0
    scores = [int(p["data"].get("score", 0)) for p in posts]
    comments = [int(p["data"].get("num_comments", 0)) for p in posts]
    n = len(scores)
    return sum(scores) / n, sum(comments) / n, n


async def _fetch_hn(cli: httpx.AsyncClient, top_n: int = 15
                   ) -> tuple[float, float, int]:
    r = await cli.get(HN_URL)
    r.raise_for_status()
    ids = r.json()[:top_n]
    coros = [cli.get(HN_ITEM.format(i)) for i in ids]
    resps = await asyncio.gather(*coros, return_exceptions=True)
    scores, comments = [], []
    for resp in resps:
        if isinstance(resp, Exception):
            continue
        try:
            it = resp.json()
        except Exception:
            continue
        scores.append(int(it.get("score", 0)))
        comments.append(int(it.get("descendants", 0)))
    n = len(scores) or 1
    return sum(scores) / n, sum(comments) / n, len(scores)


async def run(ctx) -> None:
    cfg = ctx.cfg
    period = float(cfg.get("poll_seconds", 60.0))
    async with httpx.AsyncClient(timeout=20.0) as cli:
        while True:
            try:
                r_score, r_com, r_n = await _fetch_reddit(cli)
                ctx.send("reddit", r_score, r_com, float(r_n))
            except Exception as e:  # noqa: BLE001
                LOG.warning("reddit fetch failed: %s", e)
                r_score = 0.0
            try:
                h_score, h_com, h_n = await _fetch_hn(cli)
                ctx.send("hn", h_score, h_com, float(h_n))
            except Exception as e:  # noqa: BLE001
                LOG.warning("hn fetch failed: %s", e)
                h_score = 0.0
            # Combined score normalize en [0..1] ; reddit hot ~10k+ posts,
            # HN front ~300 points. On scale chaque source puis on max.
            combined = max(min(r_score / 10000.0, 1.0),
                           min(h_score / 500.0, 1.0))
            ctx.send("pulse", combined)
            await asyncio.sleep(period)
