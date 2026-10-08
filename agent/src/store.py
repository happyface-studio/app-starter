"""Tiny async PostgREST client for the tables the agent touches (service role, bypasses RLS)."""

from __future__ import annotations

import os
from datetime import datetime, timezone
from typing import Any

import aiohttp


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


class Store:
    def __init__(self, http: aiohttp.ClientSession) -> None:
        self._url = os.environ["SUPABASE_URL"].rstrip("/") + "/rest/v1"
        key = os.environ["SUPABASE_SERVICE_ROLE_KEY"]
        self._headers = {
            "apikey": key,
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
        }
        self._http = http

    async def _request(
        self,
        method: str,
        table: str,
        *,
        params: dict[str, str] | None = None,
        body: Any = None,
        returning: bool = False,
    ) -> list[dict[str, Any]]:
        headers = dict(self._headers)
        if returning:
            headers["Prefer"] = "return=representation"
        async with self._http.request(
            method, f"{self._url}/{table}", params=params, json=body, headers=headers
        ) as res:
            if res.status >= 400:
                raise RuntimeError(f"{method} {table} failed ({res.status}): {await res.text()}")
            if res.status == 204 or not (returning or method == "GET"):
                return []
            return await res.json()

    async def desk(self, desk_id: str) -> dict[str, Any] | None:
        rows = await self._request("GET", "desks", params={"id": f"eq.{desk_id}", "select": "*"})
        return rows[0] if rows else None

    async def line_by_number(self, e164: str) -> dict[str, Any] | None:
        rows = await self._request(
            "GET", "phone_lines", params={"e164": f"eq.{e164}", "select": "*"}
        )
        return rows[0] if rows else None

    async def call(self, call_id: str) -> dict[str, Any] | None:
        rows = await self._request("GET", "calls", params={"id": f"eq.{call_id}", "select": "*"})
        return rows[0] if rows else None

    async def insert_call(self, row: dict[str, Any]) -> dict[str, Any]:
        rows = await self._request("POST", "calls", body=row, returning=True)
        return rows[0]

    async def update_call(self, call_id: str, **fields: Any) -> None:
        await self._request("PATCH", "calls", params={"id": f"eq.{call_id}"}, body=fields)
