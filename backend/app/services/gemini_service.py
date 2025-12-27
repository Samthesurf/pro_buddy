"""
Google Gemini Service for AI-powered analysis.
Handles app classification, goal alignment analysis, and progress conversations.
"""

from typing import Optional, List, Dict, Any
import json
from datetime import datetime
from google import genai
# from google.genai import types

from ..config import settings
from ..models.app_selection import AppCategory
from ..models.usage import AlignmentStatus


class GeminiService:
    """Service for interacting with Google Gemini AI."""

    def __init__(self):
        """Initialize Gemini client."""
        self.client = genai.Client(api_key=settings.gemini_api_key)
        self.model = settings.gemini_model
        
        # System prompt for progress conversations
        self.progress_system_prompt = """You are Pro Buddy, a warm, supportive AI companion helping users track their daily progress toward their goals. Your personality is:

- Encouraging but genuine (not over-the-top cheerful)
- Curious and interested in details
- Empathetic when they face challenges
- Celebratory when they achieve things
- Gently accountable without being preachy

When responding to progress updates:
1. Acknowledge what they shared specifically (don't be generic)
2. Offer genuine encouragement or support based on the situation
3. Ask ONE thoughtful follow-up question to understand more or help them reflect
4. If they mention obstacles, be understanding first, then gently curious about solutions
5. Keep responses concise (2-3 sentences + question)

Remember: You have access to their goals, so reference them when relevant."""

        # System prompt for goal discovery / motivation profiling
        self.goal_discovery_system_prompt = """You are Pro Buddy, a warm, supportive AI companion. Your job is to run a short, back-and-forth "goal discovery" conversation so the system can personalize notifications.

You MUST:
- Ask ONE question at a time (keep it short).
- Be specific and grounded in what the user already said.
- Help the user clarify: identity, primary goal, why it matters, motivators, stakes, and how they want to be nudged.
- Capture app-specific intent, especially around common distraction apps (e.g., YouTube): when it's helpful vs when it becomes avoidance.
- Keep messages concise (2-4 sentences max + ONE question).

You MUST return ONLY valid JSON in the requested schema (no markdown, no extra text)."""

    async def classify_app(
        self,
        app_name: str,
        package_name: str,
    ) -> Dict[str, Any]:
        """
        Classify an app based on its name and package.

        Args:
            app_name: Display name of the app
            package_name: Android package name

        Returns:
            Dictionary with category, description, and typical_uses
        """
        prompt = f"""Analyze the following Android app and provide classification:

App Name: {app_name}
Package Name: {package_name}

Respond with a JSON object containing:
- category: One of [productivity, social, entertainment, gaming, utility, health, education, communication, finance, news, shopping, travel, other]
- description: A brief 1-2 sentence description of what this app is typically used for
- typical_uses: An array of 3-5 common use cases for this app

Example response:
{{"category": "social", "description": "A social media platform for sharing photos and videos with friends.", "typical_uses": ["Browsing feed", "Posting photos", "Direct messaging", "Following celebrities", "Watching stories"]}}

Respond ONLY with the JSON object, no additional text."""

        try:
            response = await self.client.aio.models.generate_content(
                model=self.model,
                contents=prompt,
            )
            result = json.loads(response.text.strip())

            # Validate category
            category = result.get("category", "other").lower()
            if category not in [c.value for c in AppCategory]:
                category = "other"

            return {
                "category": category,
                "description": result.get("description", "Unknown app"),
                "typical_uses": result.get("typical_uses", []),
            }
        except Exception as e:
            print(f"Error classifying app: {e}")
            return {
                "category": "other",
                "description": f"App: {app_name}",
                "typical_uses": [],
            }

    async def analyze_alignment(
        self,
        app_name: str,
        app_classification: Dict[str, Any],
        user_goals: List[Dict[str, Any]],
        user_apps: List[Dict[str, Any]],
    ) -> Dict[str, Any]:
        """
        Analyze if app usage aligns with user's goals.

        Args:
            app_name: Name of the app being used
            app_classification: Classification info about the app
            user_goals: List of user's goals
            user_apps: List of user's approved apps with reasons

        Returns:
            Dictionary with aligned, message, and reason
        """
        # Format goals
        goals_text = "\n".join(
            [
                f"- {g.get('content', '')}"
                + (f" (Reason: {g.get('reason')})" if g.get("reason") else "")
                for g in user_goals
            ]
        )

        # Format approved apps
        apps_text = "\n".join(
            [
                f"- {a.get('app_name', '')}: {a.get('reason', 'No reason given')} (Importance: {a.get('importance', 3)}/5)"
                for a in user_apps
            ]
        )

        # Check if this is an approved app
        is_approved = any(
            a.get("app_name", "").lower() == app_name.lower() for a in user_apps
        )

        prompt = f"""You are a supportive goal accountability partner. Analyze if the current app usage aligns with the user's goals.

USER'S GOALS:
{goals_text if goals_text else "No specific goals set yet."}

USER'S APPROVED GOAL-ALIGNED APPS:
{apps_text if apps_text else "No apps specifically selected yet."}

CURRENT APP BEING USED:
Name: {app_name}
Category: {app_classification.get('category', 'unknown')}
Description: {app_classification.get('description', 'Unknown')}
Typical Uses: {', '.join(app_classification.get('typical_uses', []))}
Is Pre-Approved by User: {is_approved}

INSTRUCTIONS:
1. Determine if this app usage is ALIGNED (helps goals), NEUTRAL (neither helps nor hinders), or MISALIGNED (works against goals)
2. Generate an appropriate message:
   - For ALIGNED: Be encouraging and supportive. Vary your tone - be warm, congratulatory, or motivating.
   - For NEUTRAL: Be neutral, perhaps gently curious.
   - For MISALIGNED: Be gentle but honest. Remind them of their goals without being harsh or preachy. Be understanding.
3. Keep messages concise (1-2 sentences max)
4. Be conversational and friendly, like a supportive friend

Respond with a JSON object:
{{"alignment": "aligned|neutral|misaligned", "message": "Your friendly message here", "reason": "Brief explanation of your reasoning"}}

Respond ONLY with the JSON object."""

        try:
            response = await self.client.aio.models.generate_content(
                model=self.model,
                contents=prompt,
            )
            result = json.loads(response.text.strip())

            alignment_str = result.get("alignment", "neutral").lower()
            if alignment_str == "aligned":
                alignment = AlignmentStatus.ALIGNED
            elif alignment_str == "misaligned":
                alignment = AlignmentStatus.MISALIGNED
            else:
                alignment = AlignmentStatus.NEUTRAL

            return {
                "aligned": alignment == AlignmentStatus.ALIGNED,
                "alignment_status": alignment,
                "message": result.get("message", ""),
                "reason": result.get("reason", ""),
            }
        except Exception as e:
            print(f"Error analyzing alignment: {e}")
            return {
                "aligned": True,
                "alignment_status": AlignmentStatus.NEUTRAL,
                "message": "Keep going! You're doing great.",
                "reason": "Unable to analyze - defaulting to neutral",
            }

    async def generate_goals_summary(
        self, goals: List[Dict[str, Any]]
    ) -> str:
        """
        Generate a summary of user's goals for display.

        Args:
            goals: List of user goals

        Returns:
            A concise summary string
        """
        goals_text = "\n".join(
            [
                f"- {g.get('content', '')}"
                + (f" ({g.get('reason', '')})" if g.get("reason") else "")
                for g in goals
            ]
        )

        prompt = f"""Summarize the following goals in 1-2 encouraging sentences that capture the essence of what this person is working toward:

{goals_text}

Keep it warm, personal, and motivating. Respond with just the summary, no additional text."""

        try:
            response = await self.client.aio.models.generate_content(
                model=self.model,
                contents=prompt,
            )
            return response.text.strip()
        except Exception as e:
            print(f"Error generating summary: {e}")
            return "You're working toward meaningful goals. Keep it up!"

    async def generate_embedding(self, text: str) -> Optional[List[float]]:
        """
        Generate embedding for text using Gemini.

        Args:
            text: Text to embed

        Returns:
            List of floats representing the embedding, or None on error
        """
        try:
            result = await self.client.aio.models.embed_content(
                model="gemini-embedding-001",
                contents=text,
            )
            return result.embeddings[0].values
        except Exception as e:
            print(f"Error generating embedding: {e}")
            return None

    async def transcribe_audio(
        self,
        audio_data: bytes,
        mime_type: str = "audio/wav",
    ) -> Optional[str]:
        """
        Transcribe audio using Gemini's multimodal capabilities.

        Args:
            audio_data: Raw audio bytes
            mime_type: MIME type of the audio (e.g., "audio/wav", "audio/mp4")

        Returns:
            Transcribed text or None on error
        """
        try:
            # Upload the audio file using the Files API
            upload_response = await self.client.aio.files.upload(
                file=audio_data,
                mime_type=mime_type,
            )
            
            # Generate content with the uploaded file
            response = await self.client.aio.models.generate_content(
                model=self.model,
                contents=[
                    upload_response,
                    "Transcribe this audio to text. Provide only the transcription without any additional commentary."
                ],
            )
            
            # Delete the uploaded file to save storage
            try:
                await self.client.aio.files.delete(name=upload_response.name)
            except Exception as e:
                print(f"Warning: Failed to delete uploaded audio file: {e}")
            
            return response.text.strip()
        except Exception as e:
            print(f"Error transcribing audio: {e}")
            return None

    async def process_progress_report(
        self,
        user_message: str,
        user_goals: List[Dict[str, Any]],
        recent_progress: List[Dict[str, Any]],
        conversation_history: Optional[List[Dict[str, str]]] = None,
    ) -> Dict[str, Any]:
        """
        Process a user's progress report and generate an encouraging response.

        Args:
            user_message: The user's progress update
            user_goals: List of user's goals for context
            recent_progress: Recent progress entries for continuity
            conversation_history: Optional recent conversation for context

        Returns:
            Dictionary with message, encouragement_type, follow_up_question, detected_topics
        """
        # Format goals context
        goals_text = "\n".join(
            [f"- {g.get('content', '')}" for g in user_goals]
        ) if user_goals else "No specific goals set yet."

        # Format recent progress for context
        recent_text = ""
        if recent_progress:
            recent_entries = recent_progress[:5]  # Last 5 entries
            recent_text = "\n".join(
                [f"- {p.get('content', '')} ({p.get('date', 'recent')})" 
                 for p in recent_entries]
            )

        # Format conversation history
        history_text = ""
        if conversation_history:
            history_text = "\n".join(
                [f"{msg['role'].upper()}: {msg['content']}" 
                 for msg in conversation_history[-6:]]  # Last 3 exchanges
            )

        prompt = f"""{self.progress_system_prompt}

USER'S GOALS:
{goals_text}

RECENT PROGRESS UPDATES (for context):
{recent_text if recent_text else "This is their first progress update."}

{f"RECENT CONVERSATION:{chr(10)}{history_text}" if history_text else ""}

USER'S CURRENT MESSAGE:
{user_message}

Respond with a JSON object:
{{
    "message": "Your warm, personalized response (2-3 sentences)",
    "encouragement_type": "celebrate|support|curious|motivate",
    "follow_up_question": "A thoughtful question to continue the conversation",
    "detected_topics": ["array", "of", "topics", "mentioned"]
}}

Choose encouragement_type based on their message:
- "celebrate": They achieved something or made progress
- "support": They're struggling or facing challenges  
- "curious": Neutral update, you want to learn more
- "motivate": They seem discouraged but need a gentle push

Respond ONLY with the JSON object."""

        try:
            response = await self.client.aio.models.generate_content(
                model=self.model,
                contents=prompt,
            )
            
            # Parse the JSON response
            response_text = response.text.strip()
            # Handle potential markdown code blocks
            if response_text.startswith("```"):
                response_text = response_text.split("```")[1]
                if response_text.startswith("json"):
                    response_text = response_text[4:]
                response_text = response_text.strip()
            
            result = json.loads(response_text)
            
            return {
                "message": result.get("message", "Thanks for sharing! How else can I help?"),
                "encouragement_type": result.get("encouragement_type", "curious"),
                "follow_up_question": result.get("follow_up_question"),
                "detected_topics": result.get("detected_topics", []),
            }
        except Exception as e:
            print(f"Error processing progress report: {e}")
            return {
                "message": "Thanks for sharing your progress! Keep up the great work.",
                "encouragement_type": "support",
                "follow_up_question": "Is there anything specific you'd like to focus on?",
                "detected_topics": [],
            }

    async def chat_response(
        self,
        user_message: str,
        user_goals: List[Dict[str, Any]],
        conversation_history: List[Dict[str, str]],
    ) -> Dict[str, Any]:
        """
        Generate a chat response for general conversation.

        Args:
            user_message: The user's message
            user_goals: List of user's goals for context
            conversation_history: Recent conversation history

        Returns:
            Dictionary with message and suggestions
        """
        goals_text = "\n".join(
            [f"- {g.get('content', '')}" for g in user_goals]
        ) if user_goals else "No specific goals set."

        history_text = "\n".join(
            [f"{msg['role'].upper()}: {msg['content']}" 
             for msg in conversation_history[-10:]]
        ) if conversation_history else ""

        prompt = f"""{self.progress_system_prompt}

USER'S GOALS:
{goals_text}

CONVERSATION SO FAR:
{history_text}

USER: {user_message}

Respond naturally as Pro Buddy. Be helpful, warm, and goal-aware.

Respond with a JSON object:
{{
    "message": "Your response",
    "suggestions": ["Optional", "follow-up", "topics"]
}}

Respond ONLY with the JSON object."""

        try:
            response = await self.client.aio.models.generate_content(
                model=self.model,
                contents=prompt,
            )
            
            response_text = response.text.strip()
            if response_text.startswith("```"):
                response_text = response_text.split("```")[1]
                if response_text.startswith("json"):
                    response_text = response_text[4:]
                response_text = response_text.strip()
            
            result = json.loads(response_text)
            
            return {
                "message": result.get("message", "I'm here to help!"),
                "suggestions": result.get("suggestions", []),
            }
        except Exception as e:
            print(f"Error in chat response: {e}")
            return {
                "message": "I'm here to help you with your goals. What would you like to talk about?",
                "suggestions": ["Share today's progress", "Review my goals", "Need motivation"],
            }

    async def generate_progress_summary(
        self,
        progress_entries: List[Dict[str, Any]],
        user_goals: List[Dict[str, Any]],
        period: str = "week",
    ) -> Dict[str, Any]:
        """
        Generate a summary of user's progress over a period.

        Args:
            progress_entries: List of progress entries
            user_goals: User's goals
            period: Time period ("today", "week", "month")

        Returns:
            Dictionary with key_achievements, recurring_challenges, ai_insight
        """
        goals_text = "\n".join([f"- {g.get('content', '')}" for g in user_goals])
        
        entries_text = "\n".join(
            [f"- [{p.get('date', 'unknown')}] {p.get('content', '')}" 
             for p in progress_entries]
        )

        prompt = f"""Analyze this user's progress entries and provide a summary.

USER'S GOALS:
{goals_text}

PROGRESS ENTRIES ({period}):
{entries_text if entries_text else "No entries for this period."}

Respond with a JSON object:
{{
    "key_achievements": ["List of 2-4 notable achievements or progress made"],
    "recurring_challenges": ["List of 1-3 challenges that came up repeatedly, if any"],
    "ai_insight": "A 1-2 sentence personalized insight about their progress pattern and encouragement"
}}

Be specific to what they actually shared. If there are few entries, acknowledge that.
Respond ONLY with the JSON object."""

        try:
            response = await self.client.aio.models.generate_content(
                model=self.model,
                contents=prompt,
            )
            
            response_text = response.text.strip()
            if response_text.startswith("```"):
                response_text = response_text.split("```")[1]
                if response_text.startswith("json"):
                    response_text = response_text[4:]
                response_text = response_text.strip()
            
            result = json.loads(response_text)
            
            return {
                "key_achievements": result.get("key_achievements", []),
                "recurring_challenges": result.get("recurring_challenges", []),
                "ai_insight": result.get("ai_insight", "Keep tracking your progress!"),
            }
        except Exception as e:
            print(f"Error generating progress summary: {e}")
            return {
                "key_achievements": [],
                "recurring_challenges": [],
                "ai_insight": "Keep tracking your progress to see patterns over time!",
            }

    async def goal_discovery_step(
        self,
        user_message: Optional[str],
        conversation_history: List[Dict[str, str]],
        existing_profile: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """
        Run one step of the goal-discovery conversation.

        Returns JSON with:
          - assistant_message: str
          - done: bool
          - profile: dict (merged/updated profile fields)
        """
        existing_profile = existing_profile or {}

        # Serialize profile safely, converting datetime to ISO strings
        def _json_serial(obj):
            if hasattr(obj, 'isoformat'):
                return obj.isoformat()
            raise TypeError(f"Object of type {type(obj).__name__} is not JSON serializable")

        profile_json = json.dumps(existing_profile, ensure_ascii=False, default=_json_serial)

        history_text = "\n".join(
            [f"{m['role'].upper()}: {m['content']}" for m in conversation_history[-12:]]
        )

        prompt = f"""{self.goal_discovery_system_prompt}

CURRENT STORED PROFILE (may be partial):
{profile_json}

CONVERSATION SO FAR:
{history_text if history_text else "(none yet)"}

USER MESSAGE (may be empty if starting):
{user_message or ""}

Return ONLY JSON with this schema:
{{
  "assistant_message": "string",
  "done": true|false,
  "profile": {{
    "identity": "string|null",
    "primary_goal": "string|null",
    "why": "string|null",
    "motivators": ["string", "..."],
    "stakes": "string|null",
    "style": "gentle|direct|playful|mixed",
    "preferred_name_for_user": "string|null",
    "preferred_name_for_assistant": "string|null",
    "helpful_apps": ["string", "..."],
    "risky_apps": ["string", "..."],
    "app_intent_notes": "string|null"
  }}
}}

Rules:
- Keep existing profile fields unless the user clearly updates them.
- Never invent facts. If unknown, set null or empty list.
- Since we ask for the single most important goal, importance is implied to be maximum.
- If you have enough info to personalize notifications (identity + primary_goal + at least one motivator or stakes + style), set done=true and ask a final "confirm" question inside assistant_message.
"""

        try:
            response = await self.client.aio.models.generate_content(
                model=self.model,
                contents=prompt,
            )

            response_text = response.text.strip()
            # Handle accidental markdown code blocks
            if response_text.startswith("```"):
                response_text = response_text.split("```")[1]
                if response_text.startswith("json"):
                    response_text = response_text[4:]
                response_text = response_text.strip()

            result = json.loads(response_text)

            profile = result.get("profile") or {}
            done = bool(result.get("done", False))
            assistant_message = result.get(
                "assistant_message",
                "Tell me the goal you're most excited about right now — what is it?",
            )

            return {
                "assistant_message": assistant_message,
                "done": done,
                "profile": profile,
            }
        except Exception as e:
            print(f"Error in goal discovery step: {e}")
            # Safe fallback: ask a sensible first question
            return {
                "assistant_message": "Let’s get clear on what you’re aiming for. What’s the goal that matters most to you right now?",
                "done": False,
                "profile": existing_profile,
            }

    async def evaluate_goal_progress(
        self,
        *,
        primary_goal: str,
        conversation_text: str,
        profile: Optional[Dict[str, Any]] = None,
        previous_score: Optional[int] = None,
        previous_reason: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        Evaluate today's goal progress as a 0-100 percentage with a stored reason.

        This is used when the user exits the daily progress chat (Save & Exit).
        """
        profile = profile or {}

        # Keep payload bounded so we don't blow token limits.
        conversation_text = (conversation_text or "").strip()
        if len(conversation_text) > 12000:
            conversation_text = conversation_text[-12000:]

        identity = (profile.get("identity") or "").strip()
        why = (profile.get("why") or "").strip()
        stakes = (profile.get("stakes") or "").strip()
        motivators = profile.get("motivators") or []

        motivators_text = ""
        if isinstance(motivators, list) and motivators:
            motivators_text = ", ".join([str(m).strip() for m in motivators if str(m).strip()][:5])

        prev_text = ""
        if isinstance(previous_score, int) or isinstance(previous_reason, str):
            prev_text = (
                "PREVIOUS STORED SCORE (for continuity, optional):\n"
                f"- score_percent: {previous_score if isinstance(previous_score, int) else 'null'}\n"
                f"- reason: {previous_reason.strip() if isinstance(previous_reason, str) else ''}\n"
            )

        prompt = f"""You are a precise progress evaluator for a goal-tracking app.

USER PRIMARY GOAL:
{primary_goal}

OPTIONAL CONTEXT (do NOT invent anything beyond this):
- identity: {identity}
- why: {why}
- stakes: {stakes}
- motivators: {motivators_text}

{prev_text}
TODAY'S CONVERSATION (user + assistant):
{conversation_text if conversation_text else "(empty)"}

TASK:
1) Estimate the user's goal progress TODAY as an integer percent 0-100.
2) Provide a short stored reason explaining the score in 2-5 sentences.

SCORING RULES:
- Only use evidence from TODAY'S CONVERSATION.
- If the conversation contains no concrete actions, score should be low-to-mid (0-40).
- If they completed meaningful goal-aligned work, score can be higher (60-100).
- If they mostly reported distractions/avoidance, score should be low (0-25).
- Do not reward "plans" as much as completed actions.
- Be conservative: prefer under-scoring vs over-scoring.

OUTPUT:
Return ONLY valid JSON with this schema:
{{
  "score_percent": 0-100,
  "reason": "string"
}}

Return ONLY the JSON."""

        try:
            response = await self.client.aio.models.generate_content(
                model=self.model,
                contents=prompt,
            )

            response_text = response.text.strip()
            if response_text.startswith("```"):
                response_text = response_text.split("```")[1]
                if response_text.startswith("json"):
                    response_text = response_text[4:]
                response_text = response_text.strip()

            result = json.loads(response_text)
            score = result.get("score_percent")
            reason = str(result.get("reason") or "").strip()

            if not isinstance(score, int):
                # Gemini may return floats; coerce safely.
                try:
                    score = int(round(float(score)))
                except Exception:
                    score = 0

            score = max(0, min(100, int(score)))
            if not reason:
                reason = "No detailed reason was provided."

            return {"score_percent": score, "reason": reason}
        except Exception as e:
            print(f"Error evaluating goal progress: {e}")
            return {
                "score_percent": 0,
                "reason": "Unable to evaluate progress due to an internal error.",
            }

    async def batch_generate_use_cases(
        self,
        apps: List[Dict[str, str]],
    ) -> Dict[str, Dict[str, Any]]:
        """
        Generate use cases for multiple apps in a single Gemini call.

        Args:
            apps: List of dicts with 'app_name' and 'package_name' keys

        Returns:
            Dict mapping package_name to {use_cases: List[str], category: str}
        """
        if not apps:
            return {}

        # Batch up to 50 apps per call to avoid token limits
        batch_size = 50
        all_results = {}

        for i in range(0, len(apps), batch_size):
            batch = apps[i:i + batch_size]
            
            apps_list = "\n".join([
                f"- {app['app_name']} ({app['package_name']})"
                for app in batch
            ])

            prompt = f"""Generate common use cases for these Android apps. Focus on productivity-related use cases.

APPS:
{apps_list}

For each app, provide 3-5 short, actionable use cases (e.g., "Note-taking", "Project management", "Learning tutorials").

Respond with a JSON object where keys are package names:
{{
  "com.example.app": {{
    "use_cases": ["Use case 1", "Use case 2", "Use case 3"],
    "category": "productivity|social|entertainment|gaming|utility|health|education|communication|finance|other"
  }},
  ...
}}

Keep use cases concise (1-3 words each). Respond ONLY with the JSON object."""

            try:
                response = await self.client.aio.models.generate_content(
                    model=self.model,
                    contents=prompt,
                )
                
                response_text = response.text.strip()
                # Handle markdown code blocks
                if response_text.startswith("```"):
                    response_text = response_text.split("```")[1]
                    if response_text.startswith("json"):
                        response_text = response_text[4:]
                    response_text = response_text.strip()
                
                batch_results = json.loads(response_text)
                all_results.update(batch_results)
                
            except Exception as e:
                print(f"Error generating batch use cases: {e}")
                # Return empty use cases for failed batch
                for app in batch:
                    all_results[app['package_name']] = {
                        "use_cases": [],
                        "category": "other"
                    }

        return all_results

    async def generate_app_list(
        self,
        categories: List[str],
        count_per_category: int = 10,
    ) -> List[Dict[str, str]]:
        """
        Generate a list of popular apps for given categories.
        
        Args:
            categories: List of categories to generate apps for
            count_per_category: Number of apps to generate per category
            
        Returns:
            List of dicts with 'app_name' and 'package_name'
        """
        categories_str = ", ".join(categories)
        prompt = f"""Generate a list of popular Android apps for these specific categories: {categories_str}.
        
        For each category, list {count_per_category} distinct, real apps.
        Include a mix of very popular global apps and highly rated niche apps.
        Do NOT make up fake package names; use real ones if possible, or reasonable estimates if the exact package is unknown (e.g. com.developer.app).
        
        Respond with a JSON object containing a single list "apps":
        {{
            "apps": [
                {{"app_name": "App Name", "package_name": "com.example.package", "category": "Category Name"}},
                ...
            ]
        }}
        
        Respond ONLY with the JSON object."""
        
        try:
            response = await self.client.aio.models.generate_content(
                model=self.model,
                contents=prompt,
            )
            
            response_text = response.text.strip()
            if response_text.startswith("```"):
                response_text = response_text.split("```")[1]
                if response_text.startswith("json"):
                    response_text = response_text[4:]
                response_text = response_text.strip()
            
            result = json.loads(response_text)
            return result.get("apps", [])
            
        except Exception as e:
            print(f"Error generating app list: {e}")
            return []
