"""
Chat router for progress conversations with Gemini.
"""

from typing import Optional
from datetime import datetime
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
from ..dependencies import get_current_user


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
    """
    user_id = user["uid"]
    
    # Get services from app state
    gemini = request.app.state.gemini
    vectorize = request.app.state.vectorize
    
    try:
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
            user_message=body.message,
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
            content=body.message,
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
            content=body.message,
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









