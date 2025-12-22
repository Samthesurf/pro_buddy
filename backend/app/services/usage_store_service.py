"""
Usage Store Service.

Talks to a Cloudflare Worker (fronting D1) for:
- usage history persistence
- notification cooldown persistence
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

import httpx

from ..config import settings
from ..models.usage import AlignmentStatus, UsageFeedback


def _dt_to_utc_iso(dt: datetime) -> str:
    """Convert a datetime (naive assumed UTC) to an ISO string."""
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc).isoformat()


@dataclass(frozen=True)
class UsageStoreService:
    base_url: str
    token: str

    @property
    def configured(self) -> bool:
        return bool(self.base_url and self.token)

    def _headers(self) -> Dict[str, str]:
        return {"X-ProBuddy-Worker-Token": self.token}

    def _url(self, path: str) -> str:
        return f"{self.base_url.rstrip('/')}{path}"

    async def check_and_set_cooldown(
        self,
        *,
        user_id: str,
        package_name: str,
        alignment: AlignmentStatus,
        cooldown_seconds: int,
    ) -> bool:
        """
        Atomically check cooldown and set the last notification timestamp if allowed.
        """
        if not self.configured:
            raise RuntimeError("UsageStoreService is not configured")

        payload = {
            "user_id": user_id,
            "package_name": package_name,
            "alignment": alignment.value,
            "cooldown_seconds": int(cooldown_seconds),
        }

        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.post(
                self._url("/v1/cooldowns/check-and-set"),
                headers=self._headers(),
                json=payload,
            )
            resp.raise_for_status()
            data = resp.json()
            return bool(data.get("should_notify", False))

    async def store_usage_feedback(self, feedback: UsageFeedback) -> None:
        """Upsert a usage feedback record."""
        if not self.configured:
            raise RuntimeError("UsageStoreService is not configured")

        payload: Dict[str, Any] = {
            "id": feedback.id,
            "user_id": feedback.user_id,
            "package_name": feedback.package_name,
            "app_name": feedback.app_name,
            "alignment": feedback.alignment.value,
            "message": feedback.message,
            "reason": feedback.reason,
            "created_at": _dt_to_utc_iso(feedback.created_at),
            "notification_sent": bool(feedback.notification_sent),
        }

        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.post(
                self._url("/v1/usage-feedback"),
                headers=self._headers(),
                json=payload,
            )
            resp.raise_for_status()

    async def get_usage_history(
        self,
        *,
        user_id: str,
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None,
        limit: int = 50,
    ) -> List[Dict[str, Any]]:
        """
        Fetch usage history from the Worker.

        Returns dicts shaped like `UsageFeedback` (including `created_at` ISO string).
        """
        if not self.configured:
            raise RuntimeError("UsageStoreService is not configured")

        params: Dict[str, Any] = {"user_id": user_id, "limit": int(limit)}
        if start_date:
            params["start_ms"] = int(
                (start_date.replace(tzinfo=timezone.utc) if start_date.tzinfo is None else start_date)
                .astimezone(timezone.utc)
                .timestamp()
                * 1000
            )
        if end_date:
            params["end_ms"] = int(
                (end_date.replace(tzinfo=timezone.utc) if end_date.tzinfo is None else end_date)
                .astimezone(timezone.utc)
                .timestamp()
                * 1000
            )

        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.get(
                self._url("/v1/usage-feedback/history"),
                headers=self._headers(),
                params=params,
            )
            resp.raise_for_status()
            data = resp.json()
            items = data.get("items") or []
            if not isinstance(items, list):
                return []
            return items


usage_store_service = UsageStoreService(
    base_url=settings.usage_store_worker_url,
    token=settings.usage_store_worker_token,
)
