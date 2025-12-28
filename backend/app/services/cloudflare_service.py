"""
Cloudflare Vectorize Service for vector storage and retrieval.
Uses Cloudflare Vectorize for vector database and Workers AI for embeddings.
Stores user goals, app selections, and app classifications for semantic search.
"""

from typing import Optional, List, Dict, Any
import httpx
import json
from datetime import datetime

from ..config import settings


class CloudflareVectorizeService:
    """Service for interacting with Cloudflare Vectorize and Workers AI."""

    def __init__(self):
        """Initialize Cloudflare API client."""
        self.account_id = settings.cloudflare_account_id
        self.api_token = settings.cloudflare_api_token
        self.index_name_users = settings.vectorize_index_users
        self.index_name_apps = settings.vectorize_index_apps
        self.embedding_model = settings.cloudflare_embedding_model

        self.base_url = f"https://api.cloudflare.com/client/v4/accounts/{self.account_id}"
        self.headers = {
            "Authorization": f"Bearer {self.api_token}",
            "Content-Type": "application/json",
        }

    async def _generate_embedding(self, text: str) -> List[float]:
        """
        Generate embedding using Cloudflare Workers AI.

        Args:
            text: Text to generate embedding for

        Returns:
            List of floats representing the embedding vector
        """
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{self.base_url}/ai/run/{self.embedding_model}",
                headers=self.headers,
                json={"text": [text]},
                timeout=30.0,
            )
            response.raise_for_status()
            result = response.json()

            # Cloudflare AI returns embeddings in result.data[0]
            if result.get("success") and result.get("result", {}).get("data"):
                return result["result"]["data"][0]

            raise ValueError(f"Failed to generate embedding: {result}")

    async def _upsert_vectors(
        self,
        index_name: str,
        vectors: List[Dict[str, Any]],
    ) -> Dict[str, Any]:
        """
        Upsert vectors to Cloudflare Vectorize.

        Args:
            index_name: Name of the Vectorize index
            vectors: List of vectors with id, values, and metadata

        Returns:
            API response
        """
        # Convert vectors to NDJSON format required by Vectorize
        ndjson_lines = [json.dumps(v) for v in vectors]
        ndjson_body = "\n".join(ndjson_lines)

        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{self.base_url}/vectorize/v2/indexes/{index_name}/upsert",
                headers={
                    "Authorization": f"Bearer {self.api_token}",
                    "Content-Type": "application/x-ndjson",
                },
                content=ndjson_body,
                timeout=30.0,
            )
            # Handle 400/404 gracefully - index may not exist yet
            if response.status_code in (400, 404):
                print(f"Warning: Vectorize upsert failed ({response.status_code}): {response.text}")
                return {"success": False, "error": response.text}
            response.raise_for_status()
            return response.json()

    async def _query_vectors(
        self,
        index_name: str,
        query_vector: List[float],
        top_k: int = 10,
        filter_metadata: Optional[Dict[str, Any]] = None,
        return_values: bool = False,
        return_metadata: bool = True,
    ) -> Dict[str, Any]:
        """
        Query vectors from Cloudflare Vectorize.

        Args:
            index_name: Name of the Vectorize index
            query_vector: Query embedding vector
            top_k: Number of results to return
            filter_metadata: Optional metadata filter
            return_values: Whether to return vector values
            return_metadata: Whether to return metadata

        Returns:
            Query results
        """
        payload = {
            "vector": query_vector,
            "topK": top_k,
            "returnValues": return_values,
            "returnMetadata": "all" if return_metadata else "none",
        }

        if filter_metadata:
            payload["filter"] = filter_metadata

        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{self.base_url}/vectorize/v2/indexes/{index_name}/query",
                headers=self.headers,
                json=payload,
                timeout=30.0,
            )
            # Handle 404 gracefully - index may not exist yet
            if response.status_code == 404:
                return {"success": True, "result": {"matches": []}}
            # Handle 400 gracefully - metadata filter may not be indexed
            if response.status_code == 400:
                print(f"Warning: Vectorize query returned 400 (metadata index may not exist): {response.text}")
                return {"success": False, "result": {"matches": []}, "error": response.text}
            response.raise_for_status()
            return response.json()

    async def _delete_vectors(
        self,
        index_name: str,
        ids: List[str],
    ) -> Dict[str, Any]:
        """
        Delete vectors by IDs from Cloudflare Vectorize.

        Args:
            index_name: Name of the Vectorize index
            ids: List of vector IDs to delete

        Returns:
            API response
        """
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{self.base_url}/vectorize/v2/indexes/{index_name}/delete-by-ids",
                headers=self.headers,
                json={"ids": ids},
                timeout=30.0,
            )
            # Handle 404 gracefully - index or vectors may not exist
            if response.status_code == 404:
                return {"success": True, "result": {"count": 0}}
            response.raise_for_status()
            return response.json()

    async def _get_vectors_by_ids(
        self,
        index_name: str,
        ids: List[str],
    ) -> Dict[str, Any]:
        """
        Get vectors by IDs from Cloudflare Vectorize.

        Args:
            index_name: Name of the Vectorize index
            ids: List of vector IDs to retrieve

        Returns:
            API response with vectors, or empty result if not found
        """
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{self.base_url}/vectorize/v2/indexes/{index_name}/get-by-ids",
                headers=self.headers,
                json={"ids": ids},
                timeout=30.0,
            )
            # Handle 404 gracefully - vectors or index don't exist yet
            if response.status_code == 404:
                return {"success": True, "result": []}
            response.raise_for_status()
            return response.json()

    # ==================== User Context Methods ====================

    async def store_user_goal(
        self,
        user_id: str,
        goal_id: str,
        content: str,
        reason: Optional[str] = None,
    ) -> None:
        """Store a user's goal in the vector database."""
        document = f"Goal: {content}"
        if reason:
            document += f"\nReason: {reason}"

        # Generate embedding
        embedding = await self._generate_embedding(document)

        vector = {
            "id": f"goal_{user_id}_{goal_id}",
            "values": embedding,
            "metadata": {
                "user_id": user_id,
                "goal_id": goal_id,
                "type": "goal",
                "content": content,
                "reason": reason or "",
            },
        }

        await self._upsert_vectors(self.index_name_users, [vector])

    async def store_app_selection(
        self,
        user_id: str,
        selection_id: str,
        app_name: str,
        package_name: str,
        reason: str,
        importance: int,
    ) -> None:
        """Store a user's app selection in the vector database."""
        document = f"App: {app_name}\nWhy it helps: {reason}\nImportance: {importance}/5"

        # Generate embedding
        embedding = await self._generate_embedding(document)

        vector = {
            "id": f"app_{user_id}_{selection_id}",
            "values": embedding,
            "metadata": {
                "user_id": user_id,
                "selection_id": selection_id,
                "type": "app_selection",
                "app_name": app_name,
                "package_name": package_name,
                "reason": reason,
                "importance": importance,
            },
        }

        await self._upsert_vectors(self.index_name_users, [vector])

    async def store_onboarding_preferences(
        self,
        user_id: str,
        challenges: List[str],
        habits: List[str],
        distraction_hours: float = 0,
        focus_duration_minutes: float = 0,
        goal_clarity: int = 5,
        productive_time: str = "Morning",
        check_in_frequency: str = "Daily",
    ) -> None:
        """Store user's onboarding preferences (habits, challenges, etc.) in the vector database."""
        # Build a document for semantic search
        document_parts = []
        if challenges:
            document_parts.append(f"Challenges to overcome: {', '.join(challenges)}")
        if habits:
            document_parts.append(f"Habits to build: {', '.join(habits)}")
        document_parts.append(f"Productive time: {productive_time}")
        document_parts.append(f"Check-in frequency: {check_in_frequency}")
        document_parts.append(f"Goal clarity: {goal_clarity}/10")
        document_parts.append(f"Hours lost to distractions: {distraction_hours}")
        document_parts.append(f"Focus duration: {focus_duration_minutes} minutes")
        
        document = "\n".join(document_parts)

        # Generate embedding
        embedding = await self._generate_embedding(document)

        vector = {
            "id": f"onboarding_prefs_{user_id}",
            "values": embedding,
            "metadata": {
                "user_id": user_id,
                "type": "onboarding_preferences",
                "challenges": challenges,
                "habits": habits,
                "distraction_hours": distraction_hours,
                "focus_duration_minutes": focus_duration_minutes,
                "goal_clarity": goal_clarity,
                "productive_time": productive_time,
                "check_in_frequency": check_in_frequency,
            },
        }

        await self._upsert_vectors(self.index_name_users, [vector])

    async def get_onboarding_preferences(
        self,
        user_id: str,
    ) -> Optional[Dict[str, Any]]:
        """Retrieve user's onboarding preferences from the vector database."""
        try:
            result = await self._get_vectors_by_ids(
                self.index_name_users,
                [f"onboarding_prefs_{user_id}"],
            )
            
            if result.get("success") and result.get("result", {}).get("vectors"):
                vectors = result["result"]["vectors"]
                if vectors:
                    # Get the first (and only) vector's metadata
                    vector_data = vectors.get(f"onboarding_prefs_{user_id}")
                    if vector_data and isinstance(vector_data, dict):
                        return vector_data.get("metadata")
            return None
        except Exception as e:
            print(f"Warning: Failed to get onboarding preferences: {e}")
            return None

    async def get_user_context(
        self,
        user_id: str,
        query: Optional[str] = None,
        n_results: int = 10,
    ) -> Dict[str, Any]:
        """
        Retrieve user's goals and app selections.

        Args:
            user_id: The user's ID
            query: Optional query for semantic search
            n_results: Maximum number of results

        Returns:
            Dictionary with goals and app_selections lists
        """
        # Generate query embedding
        search_query = query or f"user {user_id} goals and apps"
        query_embedding = await self._generate_embedding(search_query)

        # Query with user_id filter
        results = await self._query_vectors(
            self.index_name_users,
            query_embedding,
            top_k=n_results,
            filter_metadata={"user_id": {"$eq": user_id}},
        )

        # Organize results by type
        goals = []
        app_selections = []

        if results.get("success") and results.get("result", {}).get("matches"):
            for match in results["result"]["matches"]:
                metadata = match.get("metadata", {})
                if metadata.get("type") == "goal":
                    goals.append(metadata)
                elif metadata.get("type") == "app_selection":
                    app_selections.append(metadata)

        return {
            "goals": goals,
            "app_selections": app_selections,
        }

    async def delete_user_data(self, user_id: str) -> None:
        """Delete all data for a user."""
        # Approach 1: Try to query for user vectors with filter
        # This may fail with 400 if metadata index is not configured
        try:
            query_embedding = await self._generate_embedding(f"user {user_id}")
            results = await self._query_vectors(
                self.index_name_users,
                query_embedding,
                top_k=1000,
                filter_metadata={"user_id": {"$eq": user_id}},
            )

            if results.get("success") and results.get("result", {}).get("matches"):
                ids_to_delete = [match["id"] for match in results["result"]["matches"]]
                if ids_to_delete:
                    await self._delete_vectors(self.index_name_users, ids_to_delete)
                    print(f"Deleted {len(ids_to_delete)} vectors via query filter.")
                    return
        except Exception as e:
            print(f"Query-based deletion failed (metadata index may not exist): {e}")
        
        # Approach 2: Try to delete by known ID patterns
        # This is a fallback when metadata filtering isn't available
        known_prefixes = [
            f"goal_{user_id}_",
            f"app_{user_id}_",
            f"onboarding_prefs_{user_id}",
            f"progress_{user_id}_",
            f"progress_session_{user_id}_",
            f"chat_{user_id}_",
            f"goalchat_{user_id}_",
            f"notification_profile_{user_id}",
        ]
        
        # We can't enumerate all IDs, but we can try to delete known patterns
        # Try deleting the notification profile and onboarding prefs directly
        known_single_ids = [
            f"onboarding_prefs_{user_id}",
            f"notification_profile_{user_id}",
        ]
        
        try:
            await self._delete_vectors(self.index_name_users, known_single_ids)
            print(f"Deleted known single-ID vectors for user {user_id}.")
        except Exception as e:
            print(f"Single-ID deletion also failed: {e}")
        
        # Note: For a complete cleanup, you would need to either:
        # 1. Create a metadata index for user_id in Vectorize settings
        # 2. Keep track of vector IDs elsewhere (e.g., D1) for deletion
        print("Warning: Some user vectors may remain. Configure metadata indexing for complete cleanup.")

    # ==================== App Knowledge Methods ====================

    async def store_app_classification(
        self,
        package_name: str,
        app_name: str,
        category: str,
        description: str,
        typical_uses: List[str],
    ) -> None:
        """Store an app classification in the knowledge base."""
        document = (
            f"App: {app_name}\n"
            f"Category: {category}\n"
            f"Description: {description}\n"
            f"Typical uses: {', '.join(typical_uses)}"
        )

        # Generate embedding
        embedding = await self._generate_embedding(document)

        vector = {
            "id": f"app_{package_name}",
            "values": embedding,
            "metadata": {
                "package_name": package_name,
                "app_name": app_name,
                "category": category,
                "description": description,
                "typical_uses": ",".join(typical_uses),
            },
        }

        await self._upsert_vectors(self.index_name_apps, [vector])

    async def get_app_classification(
        self, package_name: str
    ) -> Optional[Dict[str, Any]]:
        """Get stored classification for an app."""
        results = await self._get_vectors_by_ids(
            self.index_name_apps,
            [f"app_{package_name}"],
        )

        if results.get("success") and results.get("result"):
            vectors = results["result"]
            if vectors and len(vectors) > 0:
                metadata = vectors[0].get("metadata", {})
                # Convert typical_uses back to list
                if "typical_uses" in metadata and isinstance(metadata["typical_uses"], str):
                    metadata["typical_uses"] = metadata["typical_uses"].split(",")
                return metadata

        return None

    async def search_similar_apps(
        self, query: str, n_results: int = 5
    ) -> List[Dict[str, Any]]:
        """Search for similar apps based on description."""
        query_embedding = await self._generate_embedding(query)

        results = await self._query_vectors(
            self.index_name_apps,
            query_embedding,
            top_k=n_results,
        )

        apps = []
        if results.get("success") and results.get("result", {}).get("matches"):
            for match in results["result"]["matches"]:
                metadata = match.get("metadata", {})
                if "typical_uses" in metadata and isinstance(metadata["typical_uses"], str):
                    metadata["typical_uses"] = metadata["typical_uses"].split(",")
                apps.append(metadata)

        return apps

    # ==================== Progress & Chat Methods ====================

    async def store_progress_entry(
        self,
        user_id: str,
        entry_id: str,
        content: str,
        ai_response: str,
        topics: List[str],
        date: str,
    ) -> None:
        """
        Store a user's progress entry in the vector database.
        
        Args:
            user_id: The user's ID
            entry_id: Unique ID for this entry
            content: The user's progress message
            ai_response: The AI's response
            topics: Detected topics from the conversation
            date: ISO format date string
        """
        # Create a rich document for semantic search
        document = f"Progress: {content}\nTopics: {', '.join(topics)}"

        # Generate embedding
        embedding = await self._generate_embedding(document)

        vector = {
            "id": f"progress_{user_id}_{entry_id}",
            "values": embedding,
            "metadata": {
                "user_id": user_id,
                "entry_id": entry_id,
                "type": "progress",
                "content": content,
                "ai_response": ai_response,
                "topics": ",".join(topics),
                "date": date,
            },
        }

        await self._upsert_vectors(self.index_name_users, [vector])

    async def store_progress_session(
        self,
        *,
        user_id: str,
        date_utc: str,
        score_percent: int,
        reason: str,
        conversation_text: str,
    ) -> None:
        """
        Store a session-level embedding for today's progress chat.

        This acts as long-term memory for future scoring and reflection.
        """
        conversation_text = (conversation_text or "").strip()
        if len(conversation_text) > 12000:
            conversation_text = conversation_text[-12000:]

        # Create a rich document for semantic search / recall.
        document = (
            f"Progress Session ({date_utc})\n"
            f"Score: {int(score_percent)}/100\n"
            f"Reason: {reason}\n"
            f"Conversation:\n{conversation_text}"
        )

        embedding = await self._generate_embedding(document)
        vector = {
            "id": f"progress_session_{user_id}_{date_utc}",
            "values": embedding,
            "metadata": {
                "user_id": user_id,
                "type": "progress_session",
                "date_utc": date_utc,
                "score_percent": int(score_percent),
                "reason": reason,
            },
        }

        await self._upsert_vectors(self.index_name_users, [vector])

    async def get_recent_progress(
        self,
        user_id: str,
        n_results: int = 10,
        query: Optional[str] = None,
    ) -> List[Dict[str, Any]]:
        """
        Retrieve user's recent progress entries.
        
        Args:
            user_id: The user's ID
            n_results: Maximum number of results
            query: Optional semantic search query
            
        Returns:
            List of progress entries with metadata
        """
        # Generate query embedding
        search_query = query or f"user {user_id} recent progress updates"
        query_embedding = await self._generate_embedding(search_query)

        # Query with user_id and type filter
        results = await self._query_vectors(
            self.index_name_users,
            query_embedding,
            top_k=n_results,
            filter_metadata={"user_id": {"$eq": user_id}},
        )

        progress_entries = []
        if results.get("success") and results.get("result", {}).get("matches"):
            for match in results["result"]["matches"]:
                metadata = match.get("metadata", {})
                if metadata.get("type") == "progress":
                    # Convert topics back to list
                    if "topics" in metadata and isinstance(metadata["topics"], str):
                        metadata["topics"] = metadata["topics"].split(",") if metadata["topics"] else []
                    progress_entries.append(metadata)

        return progress_entries

    async def get_recent_progress_sessions(
        self,
        user_id: str,
        n_results: int = 5,
    ) -> List[Dict[str, Any]]:
        """
        Retrieve recent progress session memories for a user.
        """
        query_embedding = await self._generate_embedding(
            f"user {user_id} recent progress session scores"
        )

        results = await self._query_vectors(
            self.index_name_users,
            query_embedding,
            top_k=n_results,
            filter_metadata={
                "user_id": {"$eq": user_id},
                "type": {"$eq": "progress_session"},
            },
        )

        sessions: List[Dict[str, Any]] = []
        if results.get("success") and results.get("result", {}).get("matches"):
            for match in results["result"]["matches"]:
                metadata = match.get("metadata", {})
                if metadata.get("type") == "progress_session":
                    sessions.append(metadata)

        # Best-effort sort by date_utc
        sessions.sort(key=lambda x: x.get("date_utc", ""), reverse=True)
        return sessions

    async def search_progress_by_topic(
        self,
        user_id: str,
        topic: str,
        n_results: int = 10,
    ) -> List[Dict[str, Any]]:
        """
        Search user's progress entries by topic.
        
        Args:
            user_id: The user's ID
            topic: Topic to search for
            n_results: Maximum number of results
            
        Returns:
            List of matching progress entries
        """
        return await self.get_recent_progress(
            user_id=user_id,
            n_results=n_results,
            query=f"progress about {topic}",
        )

    async def store_chat_message(
        self,
        user_id: str,
        message_id: str,
        role: str,
        content: str,
        timestamp: str,
    ) -> None:
        """
        Store a chat message for conversation history.
        
        Args:
            user_id: The user's ID
            message_id: Unique message ID
            role: "user" or "assistant"
            content: Message content
            timestamp: ISO format timestamp
        """
        # Create document for embedding
        document = f"{role}: {content}"
        embedding = await self._generate_embedding(document)

        vector = {
            "id": f"chat_{user_id}_{message_id}",
            "values": embedding,
            "metadata": {
                "user_id": user_id,
                "message_id": message_id,
                "type": "chat",
                "role": role,
                "content": content,
                "timestamp": timestamp,
            },
        }

        await self._upsert_vectors(self.index_name_users, [vector])

    async def get_conversation_history(
        self,
        user_id: str,
        n_results: int = 20,
    ) -> List[Dict[str, Any]]:
        """
        Retrieve recent conversation history for a user.
        
        Args:
            user_id: The user's ID
            n_results: Maximum number of messages
            
        Returns:
            List of chat messages sorted by timestamp
        """
        query_embedding = await self._generate_embedding(f"user {user_id} chat conversation")

        results = await self._query_vectors(
            self.index_name_users,
            query_embedding,
            top_k=n_results,
            filter_metadata={"user_id": {"$eq": user_id}},
        )

        messages = []
        if results.get("success") and results.get("result", {}).get("matches"):
            for match in results["result"]["matches"]:
                metadata = match.get("metadata", {})
                if metadata.get("type") == "chat":
                    messages.append({
                        "role": metadata.get("role"),
                        "content": metadata.get("content"),
                        "timestamp": metadata.get("timestamp"),
                    })

        # Sort by timestamp
        messages.sort(key=lambda x: x.get("timestamp", ""), reverse=False)
        return messages

    # ==================== Goal Discovery (Notification Profile) ====================

    async def store_goal_discovery_message(
        self,
        user_id: str,
        session_id: str,
        message_id: str,
        role: str,
        content: str,
        timestamp: str,
    ) -> None:
        """
        Store a goal-discovery chat message (separate from general/progress chat).
        """
        document = f"{role}: {content}"
        embedding = await self._generate_embedding(document)

        vector = {
            "id": f"goalchat_{user_id}_{session_id}_{message_id}",
            "values": embedding,
            "metadata": {
                "user_id": user_id,
                "session_id": session_id,
                "message_id": message_id,
                "type": "goal_discovery_chat",
                "role": role,
                "content": content,
                "timestamp": timestamp,
            },
        }

        await self._upsert_vectors(self.index_name_users, [vector])

    async def get_goal_discovery_history(
        self,
        user_id: str,
        session_id: str,
        n_results: int = 30,
    ) -> List[Dict[str, Any]]:
        """
        Retrieve goal-discovery conversation history for a session.
        """
        query_embedding = await self._generate_embedding(
            f"user {user_id} goal discovery conversation session {session_id}"
        )

        results = await self._query_vectors(
            self.index_name_users,
            query_embedding,
            top_k=n_results,
            filter_metadata={
                "user_id": {"$eq": user_id},
                "type": {"$eq": "goal_discovery_chat"},
                "session_id": {"$eq": session_id},
            },
        )

        messages: List[Dict[str, Any]] = []
        if results.get("success") and results.get("result", {}).get("matches"):
            for match in results["result"]["matches"]:
                metadata = match.get("metadata", {})
                if metadata.get("type") == "goal_discovery_chat" and metadata.get(
                    "session_id"
                ) == session_id:
                    messages.append(
                        {
                            "role": metadata.get("role"),
                            "content": metadata.get("content"),
                            "timestamp": metadata.get("timestamp"),
                        }
                    )

        messages.sort(key=lambda x: x.get("timestamp", ""), reverse=False)
        return messages

    async def store_notification_profile(
        self,
        user_id: str,
        profile: Dict[str, Any],
    ) -> None:
        """
        Store a user's notification/goal motivation profile.

        Stored as a single upserted vector so the latest profile is always retrievable.
        """
        profile_json = json.dumps(profile, ensure_ascii=False)
        document = (
            "Notification Profile\n"
            f"Identity: {profile.get('identity') or ''}\n"
            f"Primary goal: {profile.get('primary_goal') or ''}\n"
            f"Why: {profile.get('why') or ''}\n"
            f"Motivators: {', '.join(profile.get('motivators') or [])}\n"
            f"Stakes: {profile.get('stakes') or ''}\n"
            f"Importance: {profile.get('importance_1_to_5') or ''}/5\n"
            f"Style: {profile.get('style') or ''}\n"
            f"Helpful apps: {', '.join(profile.get('helpful_apps') or [])}\n"
            f"Risky apps: {', '.join(profile.get('risky_apps') or [])}\n"
            f"Notes: {profile.get('app_intent_notes') or ''}"
        )

        embedding = await self._generate_embedding(document)
        vector = {
            "id": f"notification_profile_{user_id}",
            "values": embedding,
            "metadata": {
                "user_id": user_id,
                "type": "notification_profile",
                "profile_json": profile_json,
                "updated_at": profile.get("updated_at")
                or datetime.utcnow().isoformat(),
            },
        }

        await self._upsert_vectors(self.index_name_users, [vector])

    async def get_notification_profile(self, user_id: str) -> Optional[Dict[str, Any]]:
        """
        Retrieve the latest notification profile for a user.
        """
        results = await self._get_vectors_by_ids(
            self.index_name_users, [f"notification_profile_{user_id}"]
        )

        if results.get("success") and results.get("result"):
            vectors = results["result"]
            if vectors and len(vectors) > 0:
                metadata = vectors[0].get("metadata", {})
                if metadata.get("type") != "notification_profile":
                    return None
                raw = metadata.get("profile_json") or ""
                if not raw:
                    return None
                try:
                    return json.loads(raw)
                except Exception:
                    return None

        return None
