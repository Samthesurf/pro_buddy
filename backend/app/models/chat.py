"""
Chat models for progress conversation with Gemini.
"""

from typing import Optional, List
from datetime import datetime
from enum import Enum
from pydantic import BaseModel, Field


class MessageRole(str, Enum):
    """Role of the message sender."""
    USER = "user"
    ASSISTANT = "assistant"
    SYSTEM = "system"


class ChatMessage(BaseModel):
    """A single chat message."""
    role: MessageRole
    content: str
    timestamp: datetime = Field(default_factory=datetime.utcnow)


class ProgressReportRequest(BaseModel):
    """Request to report daily progress."""
    message: str = Field(..., min_length=1, max_length=2000)
    # Optional: for voice transcription flag
    is_voice: bool = False


class ProgressReportResponse(BaseModel):
    """Response from the AI after progress report."""
    message: str
    encouragement_type: str  # "celebrate", "support", "curious", "motivate"
    follow_up_question: Optional[str] = None
    progress_stored: bool = True
    # Tags extracted from the conversation
    detected_topics: List[str] = []


class ChatRequest(BaseModel):
    """Request for a general chat message."""
    message: str = Field(..., min_length=1, max_length=2000)
    # Include recent history for context
    include_history: bool = True
    history_limit: int = Field(default=10, ge=1, le=50)


class ChatResponse(BaseModel):
    """Response from the AI."""
    message: str
    suggestions: List[str] = []  # Suggested follow-up topics


class ConversationHistory(BaseModel):
    """A summary of conversation history."""
    messages: List[ChatMessage]
    total_count: int
    has_more: bool


class ProgressSummary(BaseModel):
    """Summary of user's progress over time."""
    period: str  # "today", "week", "month"
    total_entries: int
    key_achievements: List[str]
    recurring_challenges: List[str]
    ai_insight: str

