# Initial Concept
Goal-aligned productivity companion. A Flutter app plus FastAPI backend that:
- Captures your goals and the apps that support them.
- Monitors mobile app usage and flags aligned vs. distracting time.
- Lets you chat with an AI for encouragement, feedback, and summaries.
- Stores context (goals, approved apps, chats) for smarter follow-ups.

# Product Guide

## Target Audience
The primary audience for Pro Buddy consists of professionals and remote workers who are striving to reduce digital distractions and improve their focus during work hours.

## Vision and Problem Statement
Pro Buddy addresses the critical lack of real-time, personalized encouragement and accountability in existing productivity tools. It also tackles the challenge of staying focused amidst addictive mobile apps and helps users track their long-term progress across various life goals.

## Core Features
- **Goal & App Alignment:** Users can define specific goals and whitelist apps that support them, enabling the system to identify and flag distracting behavior.
- **AI Coaching Chat:** An intelligent, supportive chat interface powered by Gemini that provides encouragement, actionable feedback, and insightful daily summaries.
- **Usage Monitoring:** Background monitoring of mobile app activity to accurately categorize time as "aligned" or "distracting" based on user-defined goals.
- **Contextual Memory:** Utilizing vector embeddings (Cloudflare Vectorize) to maintain a deep understanding of user goals, previous conversations, and evolving context for more meaningful interactions.

## AI Coaching Philosophy
The AI coach acts as an encouraging and empathetic mentor. It focuses on providing a supportive environment where users feel understood and motivated, rather than judged, while staying accountable to their own defined objectives.
