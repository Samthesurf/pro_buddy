"""
Progress score models (conversation-based goal progress).
"""

from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, Field

from .chat import MessageRole


class ProgressScoreMessage(BaseModel):
    """A chat message used for scoring."""

    role: MessageRole
    content: str = Field(..., min_length=1, max_length=4000)
    timestamp: Optional[datetime] = None


class FinalizeTodayProgressRequest(BaseModel):
    """
    Request to finalize today's progress chat session.

    The app should send ONLY messages from today (calendar day in the user's locale).
    """

    messages: List[ProgressScoreMessage] = Field(default_factory=list, max_length=200)


class ProgressScoreItem(BaseModel):
    user_id: str
    date_utc: str  # YYYY-MM-DD
    score_percent: int = Field(..., ge=0, le=100)
    reason: str
    updated_at: Optional[datetime] = None


class FinalizeTodayProgressResponse(BaseModel):
    score: ProgressScoreItem


class LatestProgressScoreResponse(BaseModel):
    score: Optional[ProgressScoreItem] = None
