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

    async def get_app_use_cases_bulk(
        self,
        package_names: List[str],
    ) -> List[Dict[str, Any]]:
        """
        Fetch cached app use cases from D1 for multiple packages.

        Returns:
            List of dicts with package_name, app_name, use_cases, category, created_at_ms
        """
        if not self.configured or not package_names:
            return []

        payload = {"package_names": package_names}

        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.post(
                self._url("/v1/app-use-cases/bulk"),
                headers=self._headers(),
                json=payload,
            )
            resp.raise_for_status()
            data = resp.json()
            items = data.get("items") or []
            return items if isinstance(items, list) else []

    async def store_app_use_case(
        self,
        *,
        package_name: str,
        app_name: str,
        use_cases: List[str],
        category: Optional[str] = None,
    ) -> None:
        """
        Store app use cases in D1 cache.
        """
        if not self.configured:
            raise RuntimeError("UsageStoreService is not configured")

        import json as json_lib
        from datetime import datetime, timezone

        payload = {
            "package_name": package_name,
            "app_name": app_name,
            "use_cases": json_lib.dumps(use_cases),
            "category": category,
            "created_at_ms": int(datetime.now(timezone.utc).timestamp() * 1000),
        }

        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.post(
                self._url("/v1/app-use-cases"),
                headers=self._headers(),
                json=payload,
            )
            resp.raise_for_status()

    async def cleanup_empty_app_use_cases(self) -> Dict[str, Any]:
        """
        Clean up poisoned cache entries (app use cases with empty use_cases arrays).
        
        Returns:
            Dict with 'deleted_count' and 'message'
        """
        if not self.configured:
            raise RuntimeError("UsageStoreService is not configured")

        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.request(
                "DELETE",
                self._url("/v1/app-use-cases/cleanup"),
                headers=self._headers(),
            )
            resp.raise_for_status()
            return resp.json()

    # ==================== Users (Persistent Storage) ====================

    async def upsert_user(
        self,
        *,
        user_id: str,
        email: str,
        display_name: Optional[str] = None,
        photo_url: Optional[str] = None,
        onboarding_complete: bool = False,
    ) -> None:
        """Create or update a user in D1."""
        if not self.configured:
            raise RuntimeError("UsageStoreService is not configured")

        payload = {
            "id": user_id,
            "email": email,
            "display_name": display_name,
            "photo_url": photo_url,
            "onboarding_complete": onboarding_complete,
        }

        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.post(
                self._url("/v1/users"),
                headers=self._headers(),
                json=payload,
            )
            resp.raise_for_status()

    async def get_user(self, *, user_id: str) -> Optional[Dict[str, Any]]:
        """Fetch a user from D1."""
        if not self.configured:
            return None

        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.get(
                self._url("/v1/users"),
                headers=self._headers(),
                params={"user_id": user_id},
            )
            resp.raise_for_status()
            data = resp.json()
            return data.get("item")

    async def update_onboarding_status(
        self, *, user_id: str, onboarding_complete: bool
    ) -> None:
        """Update just the onboarding status for a user."""
        if not self.configured:
            raise RuntimeError("UsageStoreService is not configured")

        payload = {
            "user_id": user_id,
            "onboarding_complete": onboarding_complete,
        }

        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.post(
                self._url("/v1/users/onboarding-status"),
                headers=self._headers(),
                json=payload,
            )
            resp.raise_for_status()

    # ==================== Goals (Persistent Storage) ====================

    async def store_goal(
        self,
        *,
        goal_id: str,
        user_id: str,
        content: str,
        reason: Optional[str] = None,
        timeline: Optional[str] = None,
    ) -> None:
        """Store a goal in D1."""
        if not self.configured:
            raise RuntimeError("UsageStoreService is not configured")

        payload = {
            "id": goal_id,
            "user_id": user_id,
            "content": content,
            "reason": reason,
            "timeline": timeline,
        }

        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.post(
                self._url("/v1/goals"),
                headers=self._headers(),
                json=payload,
            )
            resp.raise_for_status()

    async def get_goals(self, *, user_id: str) -> List[Dict[str, Any]]:
        """Fetch all goals for a user from D1."""
        if not self.configured:
            return []

        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.get(
                self._url("/v1/goals"),
                headers=self._headers(),
                params={"user_id": user_id},
            )
            resp.raise_for_status()
            data = resp.json()
            return data.get("items") or []

    async def delete_goal(self, *, goal_id: str, user_id: str) -> None:
        """Delete a specific goal from D1."""
        if not self.configured:
            raise RuntimeError("UsageStoreService is not configured")

        payload = {"id": goal_id, "user_id": user_id}

        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.request(
                "DELETE",
                self._url("/v1/goals"),
                headers=self._headers(),
                json=payload,
            )
            resp.raise_for_status()

    async def delete_all_goals(self, *, user_id: str) -> None:
        """Delete all goals for a user from D1."""
        if not self.configured:
            raise RuntimeError("UsageStoreService is not configured")

        payload = {"user_id": user_id}

        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.request(
                "DELETE",
                self._url("/v1/goals/bulk"),
                headers=self._headers(),
                json=payload,
            )
            resp.raise_for_status()

    # ==================== App Selections (Persistent Storage) ====================

    async def store_app_selection(
        self,
        *,
        selection_id: str,
        user_id: str,
        package_name: str,
        app_name: str,
        reason: Optional[str] = None,
        importance_rating: int = 3,
    ) -> None:
        """Store an app selection in D1."""
        if not self.configured:
            raise RuntimeError("UsageStoreService is not configured")

        payload = {
            "id": selection_id,
            "user_id": user_id,
            "package_name": package_name,
            "app_name": app_name,
            "reason": reason,
            "importance_rating": importance_rating,
        }

        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.post(
                self._url("/v1/app-selections"),
                headers=self._headers(),
                json=payload,
            )
            resp.raise_for_status()

    async def store_app_selections_bulk(
        self, *, selections: List[Dict[str, Any]]
    ) -> None:
        """Store multiple app selections in D1."""
        if not self.configured or not selections:
            return

        payload = {"selections": selections}

        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.post(
                self._url("/v1/app-selections/bulk"),
                headers=self._headers(),
                json=payload,
            )
            resp.raise_for_status()

    async def get_app_selections(self, *, user_id: str) -> List[Dict[str, Any]]:
        """Fetch all app selections for a user from D1."""
        if not self.configured:
            return []

        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.get(
                self._url("/v1/app-selections"),
                headers=self._headers(),
                params={"user_id": user_id},
            )
            resp.raise_for_status()
            data = resp.json()
            return data.get("items") or []

    async def delete_app_selection(self, *, selection_id: str, user_id: str) -> None:
        """Delete a specific app selection from D1."""
        if not self.configured:
            raise RuntimeError("UsageStoreService is not configured")

        payload = {"id": selection_id, "user_id": user_id}

        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.request(
                "DELETE",
                self._url("/v1/app-selections"),
                headers=self._headers(),
                json=payload,
            )
            resp.raise_for_status()

    async def delete_all_app_selections(self, *, user_id: str) -> None:
        """Delete all app selections for a user from D1."""
        if not self.configured:
            raise RuntimeError("UsageStoreService is not configured")

        payload = {"user_id": user_id}

        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.request(
                "DELETE",
                self._url("/v1/app-selections/bulk"),
                headers=self._headers(),
                json=payload,
            )
            resp.raise_for_status()

    # ==================== Notification Profiles (Persistent Storage) ====================

    async def store_notification_profile(
        self, *, user_id: str, profile_data: Dict[str, Any]
    ) -> None:
        """Store a notification profile in D1."""
        if not self.configured:
            raise RuntimeError("UsageStoreService is not configured")

        payload = {
            "user_id": user_id,
            "profile_data": profile_data,
        }

        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.post(
                self._url("/v1/notification-profiles"),
                headers=self._headers(),
                json=payload,
            )
            resp.raise_for_status()

    async def get_notification_profile(
        self, *, user_id: str
    ) -> Optional[Dict[str, Any]]:
        """Fetch a notification profile from D1."""
        if not self.configured:
            return None

        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.get(
                self._url("/v1/notification-profiles"),
                headers=self._headers(),
                params={"user_id": user_id},
            )
            resp.raise_for_status()
            data = resp.json()
            item = data.get("item")
            if item:
                return item.get("profile_data")
            return None

    async def delete_notification_profile(self, *, user_id: str) -> None:
        """Delete a notification profile from D1."""
        if not self.configured:
            raise RuntimeError("UsageStoreService is not configured")

        payload = {"user_id": user_id}

        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.request(
                "DELETE",
                self._url("/v1/notification-profiles"),
                headers=self._headers(),
                json=payload,
            )
            resp.raise_for_status()


usage_store_service = UsageStoreService(
    base_url=settings.usage_store_worker_url,
    token=settings.usage_store_worker_token,
)

