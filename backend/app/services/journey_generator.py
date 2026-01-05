"""
Journey Generator Service - AI-powered journey step generation.

Uses Google Gemini to create personalized journey steps based on user's goals.
"""

from typing import Optional, List, Dict, Any
import json
import uuid
from datetime import datetime

from google import genai

from ..config import settings
from ..models.goal_journey import (
    GoalJourney,
    GoalStep,
    StepStatus,
    PathType,
    MapPosition,
)


class JourneyGeneratorService:
    """Service for generating and adjusting goal journeys using AI."""

    def __init__(self):
        """Initialize Gemini client."""
        self.client = genai.Client(api_key=settings.gemini_api_key)
        self.model = settings.gemini_model

    async def generate_journey(
        self,
        user_id: str,
        goal_content: str,
        goal_reason: Optional[str] = None,
        goal_id: Optional[str] = None,
        identity: Optional[str] = None,
        challenges: Optional[List[str]] = None,
    ) -> GoalJourney:
        """
        Generate a complete journey with AI-powered steps for achieving a goal.

        Args:
            user_id: The user's ID
            goal_content: The user's goal text
            goal_reason: Why this goal matters
            goal_id: Optional reference to existing goal
            identity: User's self-identified role/identity
            challenges: User's stated challenges

        Returns:
            A complete GoalJourney with generated steps
        """
        prompt = self._build_generation_prompt(
            goal_content=goal_content,
            goal_reason=goal_reason,
            identity=identity,
            challenges=challenges,
        )

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

            result = json.loads(response_text)
            
            # Create the journey
            journey_id = str(uuid.uuid4())
            now = datetime.utcnow()
            
            steps = self._parse_steps(
                journey_id=journey_id,
                steps_data=result.get("steps", []),
            )
            
            # Set the first step as available
            if steps:
                steps[0] = GoalStep(
                    **{**steps[0].model_dump(), "status": StepStatus.AVAILABLE}
                )

            journey = GoalJourney(
                id=journey_id,
                user_id=user_id,
                goal_id=goal_id,
                goal_content=goal_content,
                goal_reason=goal_reason,
                steps=steps,
                current_step_index=0,
                overall_progress=0.0,
                created_at=now,
                journey_started_at=now,
                is_ai_generated=True,
                ai_notes=result.get("ai_notes"),
                map_width=1000.0,
                map_height=max(2000.0, len(steps) * 300.0),
            )

            return journey

        except Exception as e:
            print(f"Error generating journey: {e}")
            # Return a fallback journey with basic steps
            return self._create_fallback_journey(
                user_id=user_id,
                goal_content=goal_content,
                goal_reason=goal_reason,
                goal_id=goal_id,
            )

    async def adjust_journey(
        self,
        journey: GoalJourney,
        current_activity: str,
        additional_context: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        Adjust journey based on user's current activity.

        Args:
            journey: The current journey
            current_activity: What the user says they're doing
            additional_context: Any extra context

        Returns:
            Dict with updated journey, changes_made list, and ai_message
        """
        prompt = self._build_adjustment_prompt(
            journey=journey,
            current_activity=current_activity,
            additional_context=additional_context,
        )

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
            
            # Apply changes to journey
            updated_journey = self._apply_adjustments(
                journey=journey,
                changes=result.get("changes", []),
                new_step_index=result.get("new_current_step_index"),
            )

            return {
                "journey": updated_journey,
                "changes_made": [c.get("description", str(c)) for c in result.get("changes", [])],
                "ai_message": result.get("ai_message", "Your journey has been updated!"),
            }

        except Exception as e:
            print(f"Error adjusting journey: {e}")
            return {
                "journey": journey,
                "changes_made": [],
                "ai_message": "I couldn't adjust your journey right now. Please try again.",
            }

    def _build_generation_prompt(
        self,
        goal_content: str,
        goal_reason: Optional[str],
        identity: Optional[str],
        challenges: Optional[List[str]],
    ) -> str:
        """Build the prompt for journey generation."""
        context_parts = []
        if identity:
            context_parts.append(f"User identifies as: {identity}")
        if challenges:
            context_parts.append(f"User's challenges: {', '.join(challenges)}")
        
        context_str = "\n".join(context_parts) if context_parts else "No additional context provided."

        return f"""You are a goal-planning assistant helping create a structured journey.

USER'S GOAL: {goal_content}
WHY IT MATTERS: {goal_reason or "Not specified"}

CONTEXT:
{context_str}

Create a journey with 5-8 actionable steps to achieve this goal. Each step should:
1. Be specific and actionable
2. Build logically on previous steps  
3. Have a realistic time estimate (in days)
4. Progress toward the final goal

Also include 1-2 alternative paths at key decision points (marked as "alternative" path_type).
The final destination is the goal itself - do NOT include it as a step.

Return ONLY valid JSON with this exact structure:
{{
  "ai_notes": "Brief encouraging overview of this journey (1-2 sentences)",
  "steps": [
    {{
      "title": "Step title (short, actionable)",
      "description": "What this step involves (2-3 sentences)",
      "estimated_days": 14,
      "path_type": "main",
      "prerequisites": [],
      "tips": ["Helpful tip 1", "Helpful tip 2"]
    }},
    {{
      "title": "Alternative approach title",
      "description": "An alternative path the user could take",
      "estimated_days": 21,
      "path_type": "alternative",
      "prerequisites": ["step_0"],
      "tips": ["Tip for alternative path"]
    }}
  ]
}}

IMPORTANT:
- Order steps logically (first step is step_0, etc.)
- Prerequisites use step indices like "step_0", "step_1"
- Keep main path to 5-7 steps
- Include 1-2 alternative branches
- estimated_days should be realistic (7-30 days typically)
- Focus on the user's specific goal and context
"""

    def _build_adjustment_prompt(
        self,
        journey: GoalJourney,
        current_activity: str,
        additional_context: Optional[str],
    ) -> str:
        """Build the prompt for journey adjustment."""
        steps_summary = "\n".join([
            f"- Step {i}: {s.display_title} ({s.status.value})"
            for i, s in enumerate(journey.main_path)
        ])
        
        current_step = journey.current_step
        current_step_name = current_step.display_title if current_step else "Unknown"

        return f"""You are helping adjust a user's goal journey based on their current activities.

GOAL: {journey.goal_content}
CURRENT STEP: {current_step_name} (index: {journey.current_step_index})

ALL STEPS:
{steps_summary}

USER SAYS THEY'RE DOING: {current_activity}
{f"ADDITIONAL CONTEXT: {additional_context}" if additional_context else ""}

Analyze if:
1. The activity aligns with current step → update title to match better
2. User is ahead → mark steps complete, advance
3. User is on different track → adjust remaining steps
4. User needs additional steps → suggest insertions

Return ONLY valid JSON:
{{
  "changes": [
    {{"type": "update_title", "step_index": 0, "new_title": "..."}},
    {{"type": "complete_step", "step_index": 0}},
    {{"type": "skip_step", "step_index": 1, "reason": "..."}}
  ],
  "ai_message": "Encouraging message about the adjustment",
  "new_current_step_index": 2
}}

Change types: update_title, complete_step, skip_step, update_status
Be conservative - only make changes that clearly match user's activity.
"""

    def _parse_steps(
        self,
        journey_id: str,
        steps_data: List[Dict[str, Any]],
    ) -> List[GoalStep]:
        """Parse AI-generated steps into GoalStep objects."""
        steps = []
        total_steps = len([s for s in steps_data if s.get("path_type", "main") == "main"])
        
        for i, step_data in enumerate(steps_data):
            is_main = step_data.get("path_type", "main") == "main"
            main_index = len([s for s in steps[:i+1] if s.path_type == PathType.MAIN]) if is_main else i
            
            # Calculate position on map
            y_pos = (main_index + 1) / (total_steps + 2)  # Leave room for start/end
            x_pos = 0.5 if is_main else (0.3 if i % 2 == 0 else 0.7)
            
            # Parse prerequisites
            prerequisites = []
            for prereq in step_data.get("prerequisites", []):
                if isinstance(prereq, str) and prereq.startswith("step_"):
                    idx = int(prereq.replace("step_", ""))
                    if idx < len(steps):
                        prerequisites.append(steps[idx].id)
            
            step = GoalStep(
                id=str(uuid.uuid4()),
                journey_id=journey_id,
                title=step_data.get("title", f"Step {i + 1}"),
                description=step_data.get("description", ""),
                order_index=i,
                status=StepStatus.LOCKED,
                prerequisites=prerequisites,
                alternatives=[],
                position=MapPosition(x=x_pos, y=y_pos, layer=i),
                path_type=PathType.MAIN if is_main else PathType.ALTERNATIVE,
                estimated_days=step_data.get("estimated_days", 14),
                metadata={"tips": step_data.get("tips", [])},
                created_at=datetime.utcnow(),
            )
            steps.append(step)
        
        return steps

    def _apply_adjustments(
        self,
        journey: GoalJourney,
        changes: List[Dict[str, Any]],
        new_step_index: Optional[int],
    ) -> GoalJourney:
        """Apply AI-suggested changes to a journey."""
        updated_steps = list(journey.steps)
        now = datetime.utcnow()
        
        for change in changes:
            change_type = change.get("type")
            step_index = change.get("step_index")
            
            if step_index is None or step_index >= len(updated_steps):
                continue
            
            step = updated_steps[step_index]
            
            if change_type == "update_title":
                updated_steps[step_index] = GoalStep(
                    **{**step.model_dump(), "custom_title": change.get("new_title")}
                )
            elif change_type == "complete_step":
                updated_steps[step_index] = GoalStep(
                    **{
                        **step.model_dump(),
                        "status": StepStatus.COMPLETED,
                        "completed_at": now,
                    }
                )
            elif change_type == "skip_step":
                updated_steps[step_index] = GoalStep(
                    **{**step.model_dump(), "status": StepStatus.SKIPPED}
                )
            elif change_type == "update_status":
                new_status = StepStatus(change.get("new_status", "locked"))
                updated_steps[step_index] = GoalStep(
                    **{**step.model_dump(), "status": new_status}
                )
        
        # Calculate new progress
        completed = sum(1 for s in updated_steps if s.status == StepStatus.COMPLETED)
        main_steps = sum(1 for s in updated_steps if s.is_on_main_path)
        new_progress = completed / main_steps if main_steps > 0 else 0.0
        
        # Update current step index if provided
        final_index = new_step_index if new_step_index is not None else journey.current_step_index
        
        return GoalJourney(
            **{
                **journey.model_dump(),
                "steps": updated_steps,
                "current_step_index": final_index,
                "overall_progress": new_progress,
                "updated_at": now,
            }
        )

    def _create_fallback_journey(
        self,
        user_id: str,
        goal_content: str,
        goal_reason: Optional[str],
        goal_id: Optional[str],
    ) -> GoalJourney:
        """Create a basic fallback journey when AI generation fails."""
        journey_id = str(uuid.uuid4())
        now = datetime.utcnow()
        
        # Generic but reasonable steps
        fallback_steps_data = [
            {
                "title": "Research and planning",
                "description": "Research what's needed to achieve your goal and create a plan.",
                "estimated_days": 7,
            },
            {
                "title": "Build foundational skills",
                "description": "Develop the core skills and knowledge needed for this goal.",
                "estimated_days": 21,
            },
            {
                "title": "Practice and apply",
                "description": "Put your learning into practice with real applications.",
                "estimated_days": 30,
            },
            {
                "title": "Refine and improve",
                "description": "Refine your approach based on what you've learned.",
                "estimated_days": 21,
            },
            {
                "title": "Final push",
                "description": "Make the final effort to achieve your goal.",
                "estimated_days": 14,
            },
        ]
        
        steps = []
        for i, data in enumerate(fallback_steps_data):
            steps.append(GoalStep(
                id=str(uuid.uuid4()),
                journey_id=journey_id,
                title=data["title"],
                description=data["description"],
                order_index=i,
                status=StepStatus.AVAILABLE if i == 0 else StepStatus.LOCKED,
                position=MapPosition(x=0.5, y=(i + 1) / 6, layer=i),
                path_type=PathType.MAIN,
                estimated_days=data["estimated_days"],
                created_at=now,
            ))
        
        return GoalJourney(
            id=journey_id,
            user_id=user_id,
            goal_id=goal_id,
            goal_content=goal_content,
            goal_reason=goal_reason,
            steps=steps,
            current_step_index=0,
            overall_progress=0.0,
            created_at=now,
            journey_started_at=now,
            is_ai_generated=True,
            ai_notes="Let's take this step by step. Here's a general path to get you started!",
        )


# Singleton instance
_journey_generator: Optional[JourneyGeneratorService] = None


def get_journey_generator() -> JourneyGeneratorService:
    """Get the journey generator service singleton."""
    global _journey_generator
    if _journey_generator is None:
        _journey_generator = JourneyGeneratorService()
    return _journey_generator
