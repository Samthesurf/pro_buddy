"""
Chat router for progress conversations with Gemini.
"""

from typing import Optional, List
from datetime import datetime, timezone
import uuid
from fastapi import APIRouter, Request, Depends, HTTPException

from ..models.chat import (
    ProgressReportRequest,
    ProgressReportResponse,
    ChatRequest,
    ChatResponse,
    ConversationHistory,
    ChatMessage,
    MessageRole,
    ProgressSummary,
)
from ..models.progress_score import (
    FinalizeTodayProgressRequest,
    FinalizeTodayProgressResponse,
    LatestProgressScoreResponse,
    ProgressScoreItem,
)
from pydantic import BaseModel
from ..dependencies import get_current_user
from ..services.usage_store_service import usage_store_service


router = APIRouter()


@router.post("/progress", response_model=ProgressReportResponse)
async def report_progress(
    request: Request,
    body: ProgressReportRequest,
    user: dict = Depends(get_current_user),
):
    """
    Report daily progress and get an encouraging AI response.
    
    The progress is stored in the vector database for future context.
    Supports both text and voice input via audio_data field.
    """
    user_id = user["uid"]
    
    # Get services from app state
    gemini = request.app.state.gemini
    vectorize = request.app.state.vectorize
    
    try:
        # Handle audio transcription if audio data is provided
        user_message = body.message
        if body.audio_data and body.is_voice:
            import base64
            try:
                # Decode base64 audio data
                audio_bytes = base64.b64decode(body.audio_data)
                mime_type = body.audio_mime_type or "audio/wav"
                
                # Transcribe audio using Gemini
                transcribed_text = await gemini.transcribe_audio(
                    audio_data=audio_bytes,
                    mime_type=mime_type,
                )
                
                if transcribed_text:
                    user_message = transcribed_text
                    print(f"Audio transcribed: {transcribed_text[:100]}...")
                else:
                    raise HTTPException(
                        status_code=400,
                        detail="Failed to transcribe audio. Please try again."
                    )
            except Exception as e:
                print(f"Error processing audio: {e}")
                raise HTTPException(
                    status_code=400,
                    detail=f"Failed to process audio: {str(e)}"
                )
        
        # Get user context (goals and recent progress)
        user_context = await vectorize.get_user_context(user_id)
        recent_progress = await vectorize.get_recent_progress(user_id, n_results=5)
        conversation_history = await vectorize.get_conversation_history(user_id, n_results=10)
        
        # Format conversation history for Gemini
        history_formatted = [
            {"role": msg["role"], "content": msg["content"]}
            for msg in conversation_history
        ]
        
        # Generate AI response
        ai_result = await gemini.process_progress_report(
            user_message=user_message,
            user_goals=user_context.get("goals", []),
            recent_progress=recent_progress,
            conversation_history=history_formatted,
        )
        
        # Combine message with follow-up question
        full_message = ai_result["message"]
        if ai_result.get("follow_up_question"):
            full_message += f" {ai_result['follow_up_question']}"
        
        # Store the progress entry
        entry_id = str(uuid.uuid4())
        timestamp = datetime.utcnow().isoformat()
        
        await vectorize.store_progress_entry(
            user_id=user_id,
            entry_id=entry_id,
            content=user_message,  # Store transcribed text if voice
            ai_response=full_message,
            topics=ai_result.get("detected_topics", []),
            date=timestamp,
        )
        
        # Store both messages in chat history
        user_msg_id = str(uuid.uuid4())
        ai_msg_id = str(uuid.uuid4())
        
        await vectorize.store_chat_message(
            user_id=user_id,
            message_id=user_msg_id,
            role="user",
            content=user_message,  # Store transcribed text if voice
            timestamp=timestamp,
        )
        
        await vectorize.store_chat_message(
            user_id=user_id,
            message_id=ai_msg_id,
            role="assistant",
            content=full_message,
            timestamp=datetime.utcnow().isoformat(),
        )
        
        return ProgressReportResponse(
            message=full_message,
            encouragement_type=ai_result["encouragement_type"],
            follow_up_question=ai_result.get("follow_up_question"),
            progress_stored=True,
            detected_topics=ai_result.get("detected_topics", []),
        )
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error in progress report: {e}")
        raise HTTPException(
            status_code=500,
            detail="Failed to process progress report"
        )





@router.post("/message", response_model=ChatResponse)
async def send_message(
    request: Request,
    body: ChatRequest,
    user: dict = Depends(get_current_user),
):
    """
    Send a general chat message and get a response.
    """
    user_id = user["uid"]
    
    gemini = request.app.state.gemini
    vectorize = request.app.state.vectorize
    
    try:
        # Get user context
        user_context = await vectorize.get_user_context(user_id)
        
        # Get conversation history if requested
        conversation_history = []
        if body.include_history:
            history = await vectorize.get_conversation_history(
                user_id, 
                n_results=body.history_limit
            )
            conversation_history = [
                {"role": msg["role"], "content": msg["content"]}
                for msg in history
            ]
        
        # Generate response
        ai_result = await gemini.chat_response(
            user_message=body.message,
            user_goals=user_context.get("goals", []),
            conversation_history=conversation_history,
        )
        
        # Store messages
        timestamp = datetime.utcnow().isoformat()
        
        await vectorize.store_chat_message(
            user_id=user_id,
            message_id=str(uuid.uuid4()),
            role="user",
            content=body.message,
            timestamp=timestamp,
        )
        
        await vectorize.store_chat_message(
            user_id=user_id,
            message_id=str(uuid.uuid4()),
            role="assistant",
            content=ai_result["message"],
            timestamp=datetime.utcnow().isoformat(),
        )
        
        return ChatResponse(
            message=ai_result["message"],
            suggestions=ai_result.get("suggestions", []),
        )
        
    except Exception as e:
        print(f"Error in chat message: {e}")
        raise HTTPException(
            status_code=500,
            detail="Failed to process message"
        )


@router.get("/history", response_model=ConversationHistory)
async def get_history(
    request: Request,
    limit: int = 20,
    user: dict = Depends(get_current_user),
):
    """
    Get conversation history for the current user.
    """
    user_id = user["uid"]
    vectorize = request.app.state.vectorize
    
    try:
        messages = await vectorize.get_conversation_history(user_id, n_results=limit + 1)
        
        has_more = len(messages) > limit
        messages = messages[:limit]
        
        chat_messages = [
            ChatMessage(
                role=MessageRole(msg["role"]),
                content=msg["content"],
                timestamp=datetime.fromisoformat(msg["timestamp"]) if msg.get("timestamp") else datetime.utcnow(),
            )
            for msg in messages
        ]
        
        return ConversationHistory(
            messages=chat_messages,
            total_count=len(chat_messages),
            has_more=has_more,
        )
        
    except Exception as e:
        print(f"Error getting history: {e}")
        raise HTTPException(
            status_code=500,
            detail="Failed to retrieve conversation history"
        )


@router.get("/summary", response_model=ProgressSummary)
async def get_progress_summary(
    request: Request,
    period: str = "week",
    user: dict = Depends(get_current_user),
):
    """
    Get an AI-generated summary of user's progress.
    
    Args:
        period: "today", "week", or "month"
    """
    user_id = user["uid"]
    
    gemini = request.app.state.gemini
    vectorize = request.app.state.vectorize
    
    if period not in ["today", "week", "month"]:
        raise HTTPException(status_code=400, detail="Invalid period. Use 'today', 'week', or 'month'")
    
    try:
        # Get user context and progress
        user_context = await vectorize.get_user_context(user_id)
        
        # Adjust results count based on period
        n_results = {"today": 10, "week": 30, "month": 100}.get(period, 30)
        progress_entries = await vectorize.get_recent_progress(user_id, n_results=n_results)
        
        # Generate summary
        summary_result = await gemini.generate_progress_summary(
            progress_entries=progress_entries,
            user_goals=user_context.get("goals", []),
            period=period,
        )
        
        return ProgressSummary(
            period=period,
            total_entries=len(progress_entries),
            key_achievements=summary_result.get("key_achievements", []),
            recurring_challenges=summary_result.get("recurring_challenges", []),
            ai_insight=summary_result.get("ai_insight", ""),
        )
        
    except Exception as e:
        print(f"Error generating summary: {e}")
        raise HTTPException(
            status_code=500,
            detail="Failed to generate progress summary"
        )


@router.get("/progress/search")
async def search_progress(
    request: Request,
    query: str,
    limit: int = 10,
    user: dict = Depends(get_current_user),
):
    """
    Search through past progress entries.
    """
    user_id = user["uid"]
    vectorize = request.app.state.vectorize
    
    try:
        results = await vectorize.get_recent_progress(
            user_id=user_id,
            n_results=limit,
            query=query,
        )
        
        return {
            "query": query,
            "results": results,
            "count": len(results),
        }
        
    except Exception as e:
        print(f"Error searching progress: {e}")
        raise HTTPException(
            status_code=500,
            detail="Failed to search progress entries"
        )


def _utc_date_key_now() -> str:
    """Return YYYY-MM-DD in UTC for 'today' score storage."""
    return datetime.now(timezone.utc).date().isoformat()


@router.post("/finalize-today", response_model=FinalizeTodayProgressResponse)
async def finalize_today(
    request: Request,
    body: FinalizeTodayProgressRequest,
    user: dict = Depends(get_current_user),
):
    """
    Finalize today's progress chat:
    - Evaluate today's conversation vs primary goal profile
    - Store score+reason in D1 (via Worker)
    - Store a session embedding in Vectorize (memory)
    """
    user_id = user["uid"]

    gemini = request.app.state.gemini
    vectorize = request.app.state.vectorize

    # Get primary goal profile from Vectorize
    profile = await vectorize.get_notification_profile(user_id)
    primary_goal = (profile or {}).get("primary_goal") if isinstance(profile, dict) else None
    primary_goal = (primary_goal or "").strip()
    if not primary_goal:
        raise HTTPException(
            status_code=400,
            detail="Missing primary goal profile. Please complete Goal Discovery first.",
        )

    # Build conversation text (today only) from request payload
    lines = []
    for m in body.messages or []:
        role = m.role.value if hasattr(m.role, "value") else str(m.role)
        content = (m.content or "").strip()
        if not content:
            continue
        lines.append(f"{role}: {content}")
    conversation_text = "\n".join(lines).strip()

    date_utc = _utc_date_key_now()

    prev_score = None
    prev_reason = None
    if usage_store_service.configured:
        try:
            prev = await usage_store_service.get_latest_progress_score(user_id=user_id)
            if isinstance(prev, dict):
                ps = prev.get("score_percent")
                if isinstance(ps, int):
                    prev_score = ps
                elif ps is not None:
                    try:
                        prev_score = int(ps)
                    except Exception:
                        prev_score = None
                prev_reason = prev.get("reason") if isinstance(prev.get("reason"), str) else None
        except Exception as e:
            print(f"Warning: failed to read previous progress score: {e}")

    # Evaluate via Gemini
    eval_result = await gemini.evaluate_goal_progress(
        primary_goal=primary_goal,
        conversation_text=conversation_text,
        profile=profile if isinstance(profile, dict) else None,
        previous_score=prev_score,
        previous_reason=prev_reason,
    )
    score_percent = int(eval_result.get("score_percent", 0) or 0)
    reason = str(eval_result.get("reason") or "").strip() or "No reason provided."
    score_percent = max(0, min(100, score_percent))

    # Persist to D1 via Worker (preferred)
    if usage_store_service.configured:
        try:
            await usage_store_service.upsert_progress_score(
                user_id=user_id,
                date_utc=date_utc,
                score_percent=score_percent,
                reason=reason,
            )
        except Exception as e:
            print(f"Warning: failed to store progress score via worker: {e}")

    # Store session embedding in Vectorize (memory)
    try:
        await vectorize.store_progress_session(
            user_id=user_id,
            date_utc=date_utc,
            score_percent=score_percent,
            reason=reason,
            conversation_text=conversation_text,
        )
    except Exception as e:
        print(f"Warning: failed to store progress session embedding: {e}")

    return FinalizeTodayProgressResponse(
        score=ProgressScoreItem(
            user_id=user_id,
            date_utc=date_utc,
            score_percent=score_percent,
            reason=reason,
            updated_at=datetime.utcnow(),
        )
    )


@router.get("/progress-score/latest", response_model=LatestProgressScoreResponse)
async def get_latest_progress_score(
    request: Request,
    user: dict = Depends(get_current_user),
):
    """
    Get the user's latest conversation-based progress score.
    """
    user_id = user["uid"]

    if not usage_store_service.configured:
        return LatestProgressScoreResponse(score=None)

    try:
        item = await usage_store_service.get_latest_progress_score(user_id=user_id)
        if not item:
            return LatestProgressScoreResponse(score=None)

        updated_at = None
        raw_updated_at = item.get("updated_at")
        if isinstance(raw_updated_at, str) and raw_updated_at:
            try:
                updated_at = datetime.fromisoformat(raw_updated_at.replace("Z", "+00:00"))
            except Exception:
                updated_at = None

        return LatestProgressScoreResponse(
            score=ProgressScoreItem(
                user_id=user_id,
                date_utc=str(item.get("date_utc") or ""),
                score_percent=int(item.get("score_percent") or 0),
                reason=str(item.get("reason") or ""),
                updated_at=updated_at,
            )
        )
    except Exception as e:
        print(f"Error getting latest progress score: {e}")
        raise HTTPException(status_code=500, detail="Failed to retrieve progress score")


class ProgressScoreHistoryResponse(BaseModel):
    items: List[ProgressScoreItem]
    total: int


@router.get("/progress-score/history", response_model=ProgressScoreHistoryResponse)
async def get_progress_score_history(
    request: Request,
    limit: int = 30,
    user: dict = Depends(get_current_user),
):
    """
    Get recent progress scores for the user (for streak calculation).
    """
    user_id = user["uid"]

    if not usage_store_service.configured:
        return ProgressScoreHistoryResponse(items=[], total=0)

    try:
        items_raw = await usage_store_service.get_progress_score_history(
            user_id=user_id, limit=limit
        )
        
        items = []
        for item in items_raw:
            updated_at = None
            raw_updated_at = item.get("updated_at")
            if isinstance(raw_updated_at, str) and raw_updated_at:
                try:
                    updated_at = datetime.fromisoformat(raw_updated_at.replace("Z", "+00:00"))
                except Exception:
                    updated_at = None

            items.append(
                ProgressScoreItem(
                    user_id=user_id,
                    date_utc=str(item.get("date_utc") or ""),
                    score_percent=int(item.get("score_percent") or 0),
                    reason=str(item.get("reason") or ""),
                    updated_at=updated_at,
                )
            )

        return ProgressScoreHistoryResponse(items=items, total=len(items))
    except Exception as e:
        print(f"Error getting progress score history: {e}")
        raise HTTPException(status_code=500, detail="Failed to retrieve progress score history")
