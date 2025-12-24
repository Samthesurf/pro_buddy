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

    async def get_latest_progress_score(
        self,
        *,
        user_id: str,
    ) -> Optional[Dict[str, Any]]:
        """
        Fetch the latest stored progress score for a user.

        Returns:
            Dict with keys: user_id, date_utc, score_percent, reason, updated_at
            or None if no score exists.
        """
        if not self.configured:
            raise RuntimeError("UsageStoreService is not configured")

        params: Dict[str, Any] = {"user_id": user_id}

        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.get(
                self._url("/v1/progress-score/latest"),
                headers=self._headers(),
                params=params,
            )
            resp.raise_for_status()
            data = resp.json()
            item = data.get("item")
            if not item or not isinstance(item, dict):
                return None
            return item

    async def get_progress_score_history(
        self,
        *,
        user_id: str,
        limit: int = 30,
    ) -> List[Dict[str, Any]]:
        """
        Fetch recent progress scores for a user (for streak calculation).

        Returns:
            List of dicts with keys: user_id, date_utc, score_percent, reason, updated_at
            Ordered by date_utc DESC (most recent first).
        """
        if not self.configured:
            raise RuntimeError("UsageStoreService is not configured")

        params: Dict[str, Any] = {"user_id": user_id, "limit": int(limit)}

        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.get(
                self._url("/v1/progress-score/history"),
                headers=self._headers(),
                params=params,
            )
            resp.raise_for_status()
            data = resp.json()
            items = data.get("items") or []
            if not isinstance(items, list):
                return []
            return items

    async def upsert_progress_score(
        self,
        *,
        user_id: str,
        date_utc: str,
        score_percent: int,
        reason: str,
    ) -> None:
        """
        Upsert a daily progress score + reason for a user.

        Args:
            date_utc: ISO day string (YYYY-MM-DD), treated as UTC date.
        """
        if not self.configured:
            raise RuntimeError("UsageStoreService is not configured")

        payload: Dict[str, Any] = {
            "user_id": user_id,
            "date_utc": date_utc,
            "score_percent": int(score_percent),
            "reason": reason,
        }

        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.post(
                self._url("/v1/progress-score/upsert"),
                headers=self._headers(),
                json=payload,
            )
            resp.raise_for_status()

    async def store_onboarding_preferences(
        self,
        *,
        user_id: str,
        challenges: List[str],
        habits: List[str],
        distraction_hours: float = 0,
        focus_duration_minutes: float = 0,
        goal_clarity: int = 5,
        productive_time: str = "Morning",
        check_in_frequency: str = "Daily",
    ) -> None:
        """
        Store user's onboarding preferences (challenges, habits, etc.) in D1.
        """
        if not self.configured:
            raise RuntimeError("UsageStoreService is not configured")

        payload: Dict[str, Any] = {
            "user_id": user_id,
            "challenges": challenges,
            "habits": habits,
            "distraction_hours": distraction_hours,
            "focus_duration_minutes": focus_duration_minutes,
            "goal_clarity": goal_clarity,
            "productive_time": productive_time,
            "check_in_frequency": check_in_frequency,
        }

        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.post(
                self._url("/v1/onboarding-preferences"),
                headers=self._headers(),
                json=payload,
            )
            resp.raise_for_status()

    async def get_onboarding_preferences(
        self,
        *,
        user_id: str,
    ) -> Optional[Dict[str, Any]]:
        """
        Fetch user's onboarding preferences from D1.

        Returns:
            Dict with challenges, habits, distraction_hours, etc.
            or None if not found.
        """
        if not self.configured:
            raise RuntimeError("UsageStoreService is not configured")

        params: Dict[str, Any] = {"user_id": user_id}

        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.get(
                self._url("/v1/onboarding-preferences"),
                headers=self._headers(),
                params=params,
            )
            resp.raise_for_status()
            data = resp.json()
            item = data.get("item")
            if not item or not isinstance(item, dict):
                return None
            return item

    async def delete_user_data(self, user_id: str) -> None:
        """
        Delete all data for a user from the Usage Store Worker (D1).
        """
        if not self.configured:
            # If not configured (e.g. local dev without worker), just log/pass
            print("UsageStoreService not configured, skipping delete_user_data")
            return

        payload = {"user_id": user_id}

        async with httpx.AsyncClient(timeout=10.0) as client:
            # We use DELETE method here, but httpx.delete doesn't support json body easily in all versions,
            # but standard says it's allowed. However, many clients/servers strip it.
            # The worker implementation checks method === "DELETE" and reads body.
            # safe to use request(method="DELETE", ...)
            resp = await client.request(
                "DELETE",
                self._url("/v1/user/data"),
                headers=self._headers(),
                json=payload,
            )
            resp.raise_for_status()


usage_store_service = UsageStoreService(
    base_url=settings.usage_store_worker_url,
    token=settings.usage_store_worker_token,
)
