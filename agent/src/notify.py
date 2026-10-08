"""Push notifications to the desk owner via OneSignal (optional).

The iOS app logs OneSignal in with the Supabase user id (NotifKit), so we target that
external id. `inAppSymbol` / `inAppColor` make the template's foreground handler show the
notification as an in-app banner instead of a system alert.
"""

from __future__ import annotations

import logging
import os

import aiohttp

logger = logging.getLogger("deskmates.notify")

ONESIGNAL_APP_ID = os.getenv("ONESIGNAL_APP_ID", "")
ONESIGNAL_API_KEY = os.getenv("ONESIGNAL_REST_API_KEY", "")


async def push(
    http: aiohttp.ClientSession,
    *,
    user_id: str,
    title: str,
    body: str,
    call_id: str,
    symbol: str = "phone.fill",
) -> None:
    if not (ONESIGNAL_APP_ID and ONESIGNAL_API_KEY):
        return
    payload = {
        "app_id": ONESIGNAL_APP_ID,
        "target_channel": "push",
        "include_aliases": {"external_id": [user_id]},
        "headings": {"en": title},
        "contents": {"en": body},
        "data": {"call_id": call_id, "inAppSymbol": symbol, "inAppColor": "#E8A33D"},
    }
    try:
        async with http.post(
            "https://api.onesignal.com/notifications",
            json=payload,
            headers={"Authorization": f"Key {ONESIGNAL_API_KEY}"},
            timeout=aiohttp.ClientTimeout(total=5),
        ) as res:
            if res.status >= 400:
                logger.warning("onesignal push failed: %s %s", res.status, await res.text())
    except Exception:
        logger.exception("onesignal push failed")
