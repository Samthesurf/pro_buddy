# Goals Feature - Comprehensive Implementation Plan

## 📋 Executive Summary

This document outlines the complete implementation plan for transforming the "Usage History" tab into a powerful **Goals Journey** feature. The feature will present users with their goal from onboarding, generate AI-powered steps to achieve it, and create an interactive, gamified "mind map" progression system that adapts based on user input.

---

## 🎯 Feature Overview

### Core Concept
The Goals feature is a **game-like, interactive world map** that visualizes the user's journey toward their primary goal. Think of it as a video game level select screen or skill tree where:

1. **Pannable/Zoomable Canvas** - Users can drag to explore the entire journey map (like game world maps)
2. **Branching Paths Visible** - Shows alternative routes you DIDN'T take (grayed out), emphasizing choice
3. **Destination at the End** - The goal displayed in RED with a destination marker (🏁 / pin icon)
4. **Estimated Time to Achievement** - Dynamic ETA displayed at top based on current pace
5. **Node-to-Node Transitions** - Animated "travel" between completed nodes
6. **Daily Progress Integration** - Check-ins automatically update map progress
7. **Celebration Animations** - Confetti and visual effects when completing sections

### User Flow
```
Goals Tab → "Are you ready to commit to your dreams?"
    ↓
[Choose Your Goal] button tapped
    ↓
POPUP appears showing:
  - Your main goal (from onboarding/goal discovery)
  - "Because..." reason
  - Two buttons: [Change] [Proceed]
    ↓
[Change] → Opens Goal Discovery to set new goal
[Proceed] → Generates journey → Opens game-like map screen
    ↓
Goal Journey screen with interactive pannable map
    → Current step highlighted with "YOU ARE HERE"
    → Destination (goal) shown in RED at end
    → User can tap nodes, log progress, or adjust path
```

---

## 🏗️ Architecture Overview

### New Components Needed

#### Frontend (Flutter/Dart)
1. **Screens**
   - `goals_screen.dart` - Main goals tab (replaces usage_history_screen)
   - `goal_journey_screen.dart` - The interactive mind map view

2. **Widgets**
   - `goal_roadmap_widget.dart` - Interactive node visualization
   - `goal_step_node.dart` - Individual step/node widget
   - `goal_progress_dialog.dart` - Dialog for logging progress
   - `goal_adjustment_sheet.dart` - Bottom sheet for AI-assisted path adjustments

3. **Models**
   - `goal_journey.dart` - Journey model with steps
   - `goal_step.dart` - Individual step model with status
   - `step_progress.dart` - Progress tracking per step

4. **Bloc/Cubit**
   - `goal_journey_cubit.dart` - Manages journey state, step generation, and updates

5. **Services**
   - Update `api_service.dart` with new endpoints

#### Backend (FastAPI/Python)
1. **Models**
   - `goal_journey.py` - Journey and step models

2. **Routers**
   - `goal_journey.py` - API endpoints for journey management

3. **Services**
   - `journey_generator_service.py` - AI-powered step generation
   - `journey_adjustment_service.py` - AI-powered path adjustments

4. **Database**
   - New D1 tables for journeys and steps

---

## 📐 Detailed Data Models

### Goal Journey Model

```dart
// lib/models/goal_journey.dart

enum StepStatus {
  locked,      // Not yet reachable (grayed out on map)
  available,   // Can be started (faded, solid outline)
  inProgress,  // Currently working on (glowing, pulsing)
  completed,   // Finished (filled with checkmark)
  skipped,     // User chose different path (crossed out, visible)
  alternative, // Alternative path not taken (grayed, shows choice)
}

enum PathType {
  main,        // The chosen/active path
  alternative, // A visible but unchosen path
  completed,   // Already traversed path
}

class MapPosition {
  final double x;  // X coordinate on canvas (0.0 - 1.0 normalized)
  final double y;  // Y coordinate on canvas (0.0 - 1.0 normalized)
  final int layer; // Depth level in the tree (0 = start, max = destination)
  
  const MapPosition({required this.x, required this.y, required this.layer});
}

class GoalStep {
  final String id;
  final String journeyId;
  final String title;              // e.g., "Learn Programming Basics"
  final String? customTitle;       // User-provided or AI-adjusted title
  final String description;        // What this step entails
  final int order;                 // Position in the journey
  final StepStatus status;
  final List<String> prerequisites; // IDs of steps that must be completed first
  final List<String> alternatives;  // IDs of alternative steps (show as branches)
  final DateTime? startedAt;
  final DateTime? completedAt;
  final List<String> notes;        // User's notes/logs on this step
  final Map<String, dynamic>? metadata; // AI-generated context
  
  // For map visualization
  final MapPosition position;      // Where to render on the canvas
  final PathType pathType;         // Is this main path or alternative?
  
  // For ETA calculation
  final int estimatedDays;         // AI-estimated days to complete
  final int? actualDaysSpent;      // How long it actually took
  
  // Computed
  String get displayTitle => customTitle ?? title;
  bool get isUnlocked => status != StepStatus.locked && status != StepStatus.alternative;
  bool get isOnMainPath => pathType == PathType.main || pathType == PathType.completed;
}

class GoalJourney {
  final String id;
  final String userId;
  final String goalId;             // Reference to the primary goal
  final String goalContent;        // The actual goal text (DESTINATION)
  final String? goalReason;        // Why from NotificationProfile
  final List<GoalStep> steps;      // All steps including alternatives
  final List<GoalStep> mainPath;   // Just the chosen path steps
  final int currentStepIndex;      // Which step is active on main path
  final double overallProgress;    // 0.0 to 1.0
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime journeyStartedAt; // When user started the journey
  final bool isAIGenerated;        // Was this auto-generated?
  final String? aiNotes;           // AI's summary of the journey
  
  // For ETA calculation
  final ETAData etaData;           // Estimated time of achievement data
  
  // Canvas bounds (for pan/zoom limits)
  final double mapWidth;           // Total canvas width
  final double mapHeight;          // Total canvas height
}

/// ETA (Estimated Time of Achievement) Data Model
class ETAData {
  final DateTime? estimatedCompletionDate;  // Calculated target date
  final int totalEstimatedDays;             // Sum of all step estimates
  final int daysElapsed;                    // Days since journey started
  final int stepsCompleted;                 // Number of completed steps
  final double averageDaysPerStep;          // Based on actual performance
  final double velocityScore;               // How fast vs estimated (1.0 = on track)
  final String displayText;                 // e.g., "~3 months to go"
  
  const ETAData({
    this.estimatedCompletionDate,
    required this.totalEstimatedDays,
    required this.daysElapsed,
    required this.stepsCompleted,
    required this.averageDaysPerStep,
    required this.velocityScore,
    required this.displayText,
  });
}
```

---

## ⏱️ ETA Calculation Logic (No API Required)

The Estimated Time of Achievement is calculated **entirely on the client side** using local data. Here's the complete algorithm:

### ETA Calculation Algorithm

```dart
/// lib/services/eta_calculator.dart

class ETACalculator {
  
  /// Main calculation method - returns ETAData
  static ETAData calculate(GoalJourney journey) {
    final now = DateTime.now();
    final journeyStart = journey.journeyStartedAt;
    final daysElapsed = now.difference(journeyStart).inDays;
    
    // Get completed steps with actual duration data
    final completedSteps = journey.mainPath
        .where((s) => s.status == StepStatus.completed)
        .toList();
    
    final remainingSteps = journey.mainPath
        .where((s) => s.status != StepStatus.completed && s.status != StepStatus.skipped)
        .toList();
    
    // ─────────────────────────────────────────────────
    // STEP 1: Calculate average days per step (actual)
    // ─────────────────────────────────────────────────
    double avgDaysPerStep;
    
    if (completedSteps.isEmpty) {
      // No data yet - use AI estimates
      avgDaysPerStep = _getAverageEstimatedDays(remainingSteps);
    } else {
      // Calculate based on actual performance
      final totalActualDays = completedSteps.fold<int>(
        0, (sum, step) => sum + (step.actualDaysSpent ?? step.estimatedDays)
      );
      avgDaysPerStep = totalActualDays / completedSteps.length;
    }
    
    // ─────────────────────────────────────────────────
    // STEP 2: Calculate velocity score
    // ─────────────────────────────────────────────────
    // Velocity > 1.0 = ahead of schedule
    // Velocity = 1.0 = on track
    // Velocity < 1.0 = behind schedule
    double velocityScore = 1.0;
    
    if (completedSteps.isNotEmpty) {
      final expectedDaysForCompleted = completedSteps.fold<int>(
        0, (sum, step) => sum + step.estimatedDays
      );
      final actualDaysForCompleted = completedSteps.fold<int>(
        0, (sum, step) => sum + (step.actualDaysSpent ?? step.estimatedDays)
      );
      
      if (actualDaysForCompleted > 0) {
        velocityScore = expectedDaysForCompleted / actualDaysForCompleted;
      }
    }
    
    // ─────────────────────────────────────────────────
    // STEP 3: Estimate remaining days
    // ─────────────────────────────────────────────────
    int estimatedRemainingDays;
    
    if (completedSteps.isEmpty) {
      // Use AI estimates directly
      estimatedRemainingDays = remainingSteps.fold<int>(
        0, (sum, step) => sum + step.estimatedDays
      );
    } else {
      // Use actual average, adjusted by velocity
      estimatedRemainingDays = (remainingSteps.length * avgDaysPerStep / velocityScore).round();
    }
    
    // ─────────────────────────────────────────────────
    // STEP 4: Calculate estimated completion date
    // ─────────────────────────────────────────────────
    final estimatedCompletion = now.add(Duration(days: estimatedRemainingDays));
    
    // ─────────────────────────────────────────────────
    // STEP 5: Generate human-readable display text
    // ─────────────────────────────────────────────────
    final displayText = _formatETADisplay(estimatedRemainingDays, velocityScore);
    
    return ETAData(
      estimatedCompletionDate: estimatedCompletion,
      totalEstimatedDays: journey.mainPath.fold(0, (sum, s) => sum + s.estimatedDays),
      daysElapsed: daysElapsed,
      stepsCompleted: completedSteps.length,
      averageDaysPerStep: avgDaysPerStep,
      velocityScore: velocityScore,
      displayText: displayText,
    );
  }
  
  static double _getAverageEstimatedDays(List<GoalStep> steps) {
    if (steps.isEmpty) return 14.0; // Default 2 weeks
    return steps.fold(0, (sum, s) => sum + s.estimatedDays) / steps.length;
  }
  
  static String _formatETADisplay(int daysRemaining, double velocity) {
    String timeText;
    
    if (daysRemaining <= 0) {
      timeText = "Almost there!";
    } else if (daysRemaining <= 7) {
      timeText = "~${daysRemaining} days to go";
    } else if (daysRemaining <= 30) {
      final weeks = (daysRemaining / 7).round();
      timeText = "~$weeks week${weeks > 1 ? 's' : ''} to go";
    } else if (daysRemaining <= 365) {
      final months = (daysRemaining / 30).round();
      timeText = "~$months month${months > 1 ? 's' : ''} to go";
    } else {
      final years = (daysRemaining / 365).round();
      timeText = "~$years year${years > 1 ? 's' : ''} to go";
    }
    
    // Add velocity indicator
    if (velocity >= 1.3) {
      return "🚀 $timeText (ahead of schedule!)";
    } else if (velocity >= 0.9) {
      return "✨ $timeText (on track)";
    } else if (velocity >= 0.7) {
      return "📊 $timeText (a bit behind)";
    } else {
      return "💪 $timeText (let's pick up the pace!)";
    }
  }
}
```

### ETA Recalculation Triggers

The ETA is recalculated automatically when:

1. **Step completed** - `actualDaysSpent` is recorded, averages update
2. **Daily progress logged** - Affects current step's elapsed time
3. **Path adjusted** - Remaining steps change, recalculate total
4. **Journey loaded** - Fresh calculation on app open

### ETA Display in UI

```
┌─────────────────────────────────────┐
│  🎯 Become a Software Engineer      │
│  ━━━━━━━━━━━━━ 35%                  │
│                                     │
│  🚀 ~3 months to go (ahead!)        │ ← ETA Display
│                                     │
```

### Backend Pydantic Models

```python
# backend/app/models/goal_journey.py

from enum import Enum
from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, Field

class StepStatus(str, Enum):
    LOCKED = "locked"
    AVAILABLE = "available"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    SKIPPED = "skipped"

class GoalStep(BaseModel):
    id: str
    journey_id: str
    title: str
    custom_title: Optional[str] = None
    description: str
    order: int
    status: StepStatus = StepStatus.LOCKED
    prerequisites: List[str] = Field(default_factory=list)
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    notes: List[str] = Field(default_factory=list)
    metadata: Optional[dict] = None

class GoalJourney(BaseModel):
    id: str
    user_id: str
    goal_id: str
    goal_content: str
    goal_reason: Optional[str] = None
    steps: List[GoalStep]
    current_step_index: int = 0
    overall_progress: float = 0.0
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: Optional[datetime] = None
    is_ai_generated: bool = True
    ai_notes: Optional[str] = None

class JourneyAdjustmentRequest(BaseModel):
    """When user tells AI what they're currently doing"""
    journey_id: str
    current_activity: str  # e.g., "I'm learning data structures and algorithms"
    additional_context: Optional[str] = None

class JourneyAdjustmentResponse(BaseModel):
    journey: GoalJourney
    changes_made: List[str]  # Description of what changed
    ai_message: str  # Encouraging message about the adjustment
```

---

## 🗄️ Database Schema

### D1 Tables (Cloudflare Worker)

```sql
-- migrations/0004_goal_journeys.sql

-- Goal journeys table
CREATE TABLE IF NOT EXISTS goal_journeys (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    goal_id TEXT,
    goal_content TEXT NOT NULL,
    goal_reason TEXT,
    current_step_index INTEGER DEFAULT 0,
    overall_progress REAL DEFAULT 0.0,
    is_ai_generated INTEGER DEFAULT 1,
    ai_notes TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_journeys_user ON goal_journeys(user_id);

-- Goal steps table
CREATE TABLE IF NOT EXISTS goal_steps (
    id TEXT PRIMARY KEY,
    journey_id TEXT NOT NULL,
    title TEXT NOT NULL,
    custom_title TEXT,
    description TEXT,
    order_index INTEGER NOT NULL,
    status TEXT DEFAULT 'locked',
    prerequisites TEXT, -- JSON array of step IDs
    started_at TEXT,
    completed_at TEXT,
    notes TEXT, -- JSON array of notes
    metadata TEXT, -- JSON object
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (journey_id) REFERENCES goal_journeys(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_steps_journey ON goal_steps(journey_id);
CREATE INDEX IF NOT EXISTS idx_steps_status ON goal_steps(status);
```

---

## 🔌 API Endpoints

### New Endpoints Needed

```
# Journey Management
POST   /api/journey/generate          - Generate journey from goal
GET    /api/journey                   - Get user's current journey
GET    /api/journey/{journey_id}      - Get specific journey
PUT    /api/journey/{journey_id}      - Update journey metadata

# Step Management  
PUT    /api/journey/steps/{step_id}/status   - Update step status
PUT    /api/journey/steps/{step_id}/title    - Update step title
POST   /api/journey/steps/{step_id}/notes    - Add note to step

# AI-Powered Adjustments
POST   /api/journey/adjust            - Adjust journey based on user input
POST   /api/journey/recalculate       - Recalculate progress based on logs
```

---

## 🎨 UI/UX Design

### 1. Goals Tab (Main View) - `goals_screen.dart`

**Initial State (No Journey Started Yet):**
```
┌─────────────────────────────────────┐
│                                     │
│                                     │
│      [Inspiring illustration]       │
│      (person climbing mountain      │
│       or reaching for stars)        │
│                                     │
│                                     │
│   "Are you ready to commit to       │
│         your dreams?"               │
│                                     │
│                                     │
│       [ Choose Your Goal ]          │ ← Tapping this opens popup
│       (Primary button)              │
│                                     │
│                                     │
└─────────────────────────────────────┘
```

**Goal Confirmation Popup (appears when button is tapped):**
```
┌─────────────────────────────────────────┐
│                                         │
│         🎯 Your Main Goal               │
│                                         │
│   ┌─────────────────────────────────┐  │
│   │                                 │  │
│   │  "Become a Software Engineer"  │  │
│   │                                 │  │
│   │  ───────────────────────────── │  │
│   │                                 │  │
│   │  Because I want to build       │  │
│   │  products that help people     │  │
│   │                                 │  │
│   └─────────────────────────────────┘  │
│                                         │
│   ┌───────────────┐ ┌───────────────┐  │
│   │    Change     │ │    Proceed    │  │
│   │  (outlined)   │ │   (filled)    │  │
│   └───────────────┘ └───────────────┘  │
│                                         │
│   ─────────────────────────────────    │
│   This is the goal you set during      │
│   onboarding. You can change it or     │
│   proceed to start your journey.       │
│                                         │
└─────────────────────────────────────────┘

Actions:
- [Change] → Opens Goal Discovery flow to set a new goal
- [Proceed] → Generates journey & navigates to game-like map
```

**After Proceed - Journey View (separate screen: `goal_journey_screen.dart`):**
- This is the full game-like pannable map
- See "Active Journey State" below


**Active Journey State (Full Game-Like Map):**
```
┌─────────────────────────────────────────────────┐
│  🎯 Become a Software Engineer         [⚙️]    │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━ 35%                │
│  🚀 ~3 months to go (ahead of schedule!)       │ ← ETA Display
├─────────────────────────────────────────────────┤
│                                                 │
│  ┌─────────────────────────────────────────┐   │
│  │          PANNABLE/ZOOMABLE CANVAS       │   │
│  │  ← drag to explore, pinch to zoom →     │   │
│  │                                         │   │
│  │     ✅ START                            │   │
│  │      │                                  │   │
│  │     ✅ Learn Basics                     │   │
│  │      │                                  │   │
│  │     ┌┴──────────┐                       │   │
│  │     │           │                       │   │
│  │   ◉ YOU      ░░░ Frontend Path ░░░      │   │ ← YOU = current
│  │ "Data        (alternative - grayed)     │   │ ← Alternative path
│  │  Structures"                            │   │   shown but not taken
│  │     │                                   │   │
│  │     │                                   │   │
│  │   ○ Algorithms                          │   │
│  │     │                                   │   │
│  │     │                                   │   │
│  │  ┌──┴──────────┐                        │   │
│  │  │             │                        │   │
│  │○ Build      ░░░ Freelance Path ░░░      │   │ ← Another choice point
│  │ Projects    (alternative)               │   │
│  │  │                                      │   │
│  │  │                                      │   │
│  │                                         │   │
│  │  ┌───────────────────────────┐          │   │
│  │  │  🔴 DESTINATION 📍        │          │   │ ← RED marker
│  │  │  ┌─────────────────────┐  │          │   │
│  │  │  │ Get First           │  │          │   │
│  │  │  │ Software Engineer   │  │          │   │
│  │  │  │ Job! 🎉             │  │          │   │
│  │  │  └─────────────────────┘  │          │   │
│  │  │   ≋≋≋ YOU ARE HERE ≋≋≋   │          │   │
│  │  │    ↑ 4 steps away        │          │   │
│  │  └───────────────────────────┘          │   │
│  │                                         │   │
│  └─────────────────────────────────────────┘   │
│                                                 │
│    [ 📝 Log Progress ]    [ 🔄 Adjust Path ]   │
│                                                 │
└─────────────────────────────────────────────────┘

LEGEND:
  ✅ = Completed (traveled path, green)
  ◉  = In Progress / YOU ARE HERE (glowing, pulsing)
  ○  = Available (can start, faded)
  ░  = Alternative path not taken (very faded, shows choice)
  🔴 = Destination (red with pin marker)
```

### 2. Node/Step States Visual Design

| State | Visual | Color | Interaction |
|-------|--------|-------|-------------|
| Locked | Grayed out, dotted outline, padlock icon | `#666666` (gray) | Not tappable |
| Available | Faded color, solid outline, empty circle | `#4A90D9` (light blue) | Tap to start |
| In Progress | Bright color, **glowing/pulsing anim**, filled circle | `#FFD700` (gold) | Tap to log progress |
| Completed | Filled with ✅ checkmark, solid | `#4CAF50` (green) | Tap to view notes |
| Skipped | Crossed out but visible, strikethrough | `#999999` (light gray) | Historical reference |
| Alternative | Very faded, dashed outline, shows "path not taken" | `#333333` (dark gray) | Not tappable (display only) |
| **Destination** | **RED with pin 📍 marker, pulsing beacon** | `#FF4444` (red) | Shows goal, tap for info |

### Destination Node Special Design

The final destination node (the user's goal) has unique styling:

```dart
// Destination node is rendered differently
class DestinationNode extends StatelessWidget {
  // Features:
  // 1. RED background with glow/shadow effect
  // 2. 📍 Pin marker icon on top
  // 3. Pulsing beacon animation (subtle rings emanating)
  // 4. "X steps away" label below
  // 5. Flag/finish line decoration (🏁)
  // 6. Slightly larger than other nodes
}
```

Visual mockup of destination:
```
        ╭──────────────────╮
        │   📍 DESTINATION │
        │  ╭──────────────╮│
        │  │   🎯 Get     ││
        │  │ First SE Job ││
        │  │     🏁       ││
        │  ╰──────────────╯│
        │   4 steps away   │
        ╰──────────────────╯
             ╲ ╲ ╲ ← pulsing beacon rings
```

### 3. Progress Dialog

When user taps "Log Progress" or taps their current step:

```
┌─────────────────────────────────────┐
│  📍 Current Step                    │
│  "Learning Data Structures"         │
│                                     │
│  What are you working on?           │
│  ┌─────────────────────────────┐   │
│  │ I just finished learning    │   │
│  │ linked lists and moving on  │   │
│  │ to trees...                 │   │
│  └─────────────────────────────┘   │
│                                     │
│  ◉ Still working on this step      │
│  ○ Ready to move to next step      │
│  ○ This isn't quite right...       │
│                                     │
│  [ Cancel ]        [ Save Progress ]│
└─────────────────────────────────────┘
```

### 4. Adjust Path Bottom Sheet

When user says "This isn't quite right" or taps "Adjust Path":

```
┌─────────────────────────────────────┐
│  🔄 Adjust Your Journey             │
│                                     │
│  Tell me what you're actually       │
│  doing right now:                   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ I'm actually focusing on    │   │
│  │ learning algorithms first,  │   │
│  │ specifically sorting and    │   │
│  │ searching...                │   │
│  └─────────────────────────────┘   │
│                                     │
│  [ Cancel ]     [ Let AI Adjust ]   │
│                                     │
│  ─────────────────────────────────  │
│  AI will review your path and       │
│  suggest adjustments based on       │
│  your current focus.                │
└─────────────────────────────────────┘
```

---

## 🧠 AI Integration

### 1. Journey Generation Prompt

```
You are a goal-planning assistant. Given a user's goal, create a structured 
journey with 5-8 actionable steps to achieve it.

User's Goal: {goal_content}
Why it matters: {goal_reason}
User's identity: {identity from notification profile}
User's challenges: {challenges from onboarding}

Create a journey with steps that are:
1. Specific and actionable
2. Logically sequenced (some can be parallel)
3. Achievable within reasonable timeframes
4. Building on each other toward the final goal

Return as JSON:
{
  "ai_notes": "Brief encouraging overview of this journey",
  "steps": [
    {
      "title": "Step title",
      "description": "What this step involves",
      "prerequisites": [], // IDs of steps that must come before
      "estimated_duration": "2-4 weeks",
      "tips": ["tip1", "tip2"]
    }
  ]
}
```

### 2. Journey Adjustment Prompt

```
You are helping a user adjust their goal journey based on their current activities.

Original goal: {goal_content}
Current journey steps: {current_steps_json}
User's current step: {current_step_title}
User says they're doing: {current_activity}

Analyze if:
1. The user's activity aligns with their current step (just update title/progress)
2. The user is ahead (skip steps, advance progress)
3. The user is on a different path (adjust remaining steps)
4. The user needs additional steps inserted

Return as JSON:
{
  "changes": [
    {"type": "rename", "step_id": "x", "new_title": "..."},
    {"type": "skip", "step_id": "y"},
    {"type": "insert_after", "after_step_id": "z", "new_step": {...}},
    {"type": "update_status", "step_id": "w", "new_status": "in_progress"}
  ],
  "ai_message": "Encouraging message about the adjustment",
  "new_current_step_index": 2
}
```

### 3. Progress Integration

When user logs daily progress (existing feature), the backend should:
1. Analyze if the progress relates to their goal journey
2. Update step status/notes automatically
3. Adjust overall journey progress percentage

---

## 📱 Flutter Implementation Details

### 1. Mind Map Visualization

**Recommended: Custom Canvas + `graphview` package hybrid approach**

```dart
// Using graphview for layout algorithm, custom painting for aesthetics
dependencies:
  graphview: ^1.2.1  # For tree layout algorithms

// Custom implementation for:
// - Node widgets with status-based styling
// - Animated connecting lines
// - Progress indicators on edges
// - Tap/interaction handling
```

### 2. State Management (Bloc Pattern)

```dart
// lib/bloc/goal_journey_cubit.dart

class GoalJourneyState {
  final GoalJourney? journey;
  final bool isLoading;
  final bool isGenerating;
  final String? error;
  final GoalStep? selectedStep;
  
  // For optimistic updates
  final Map<String, StepStatus> pendingStatusChanges;
}

class GoalJourneyCubit extends Cubit<GoalJourneyState> {
  // Methods:
  // - loadJourney()
  // - generateJourney() - Called when user first enters
  // - updateStepStatus(stepId, status)
  // - addStepNote(stepId, note)
  // - adjustJourney(currentActivity)
  // - refreshFromDailyProgress() - Sync with logging
}
```

### 3. Navigation Updates

```dart
// Update main_screen.dart
// Replace UsageHistoryScreen with GoalsScreen
// Update NavigationBar destination:
NavigationDestination(
  icon: Icon(Icons.flag_outlined),
  selectedIcon: Icon(Icons.flag_rounded),
  label: 'Goals',
),
```

---

## 🎮 Gamification Elements - THE GAME

This section is **the heart of the feature** - making the journey feel like a game level, not just a to-do list.

### 1. Interactive Canvas (Game World Map)

```dart
/// The map is rendered using InteractiveViewer for pan/zoom
class GoalJourneyMap extends StatefulWidget {
  // Features:
  // - Pan: Drag to move around the map
  // - Zoom: Pinch to zoom in/out (min 0.5x, max 3.0x)
  // - Boundaries: Can't pan beyond the journey bounds
  // - Auto-center: Initially centers on current step
  // - Smooth animations when auto-navigating
}

// Implementation using InteractiveViewer
InteractiveViewer(
  boundaryMargin: EdgeInsets.all(100),
  minScale: 0.5,
  maxScale: 3.0,
  constrained: false,
  child: CustomPaint(
    size: Size(journey.mapWidth, journey.mapHeight),
    painter: JourneyMapPainter(journey: journey),
  ),
)
```

### 2. Node-to-Node Travel Animation 🚀

**When a step is completed, animate the "avatar" traveling to the next node:**

```dart
/// lib/widgets/journey_travel_animation.dart

class JourneyTravelAnimation extends StatefulWidget {
  final GoalStep fromStep;
  final GoalStep toStep;
  final VoidCallback onComplete;
  
  // Animation sequence (total ~2.5 seconds):
  // 1. Celebration burst at current node (0.5s)
  // 2. Avatar/marker moves along path (1.5s - eased curve)
  // 3. Arrival celebration at new node (0.5s)
  // 4. New node "activates" with glow
}

class _JourneyTravelAnimationState extends State<JourneyTravelAnimation>
    with TickerProviderStateMixin {
  
  late AnimationController _travelController;
  late Animation<Offset> _positionAnimation;
  late Animation<double> _scaleAnimation;
  
  @override
  void initState() {
    super.initState();
    
    _travelController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    // Curved path animation (not straight line!)
    _positionAnimation = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween(
          begin: widget.fromStep.position.toOffset(),
          end: _calculateMidpoint(), // Arc through midpoint
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: _calculateMidpoint(),
          end: widget.toStep.position.toOffset(),
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_travelController);
    
    // Scale pulse during travel
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.2), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 25),
    ]).animate(_travelController);
  }
  
  // The traveling "avatar" - a glowing orb with trail
  Widget _buildTravelingAvatar() {
    return AnimatedBuilder(
      animation: _travelController,
      builder: (context, child) {
        return Positioned(
          left: _positionAnimation.value.dx,
          top: _positionAnimation.value.dy,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Colors.amber, Colors.orange, Colors.transparent],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.6),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(Icons.star, color: Colors.white, size: 24),
            ),
          ),
        );
      },
    );
  }
}
```

**Visual representation of travel:**
```
Step A (completed)          Step B (next)
    ✅ ═══════════════════════> ◉
         ↑                       ↑
    Start here              Arrive here
         
    Animation phases:
    1. ✅ 💥 (burst)
    2. ✅ ───⭐───> ◉ (orb travels with trail)
    3. ✅ ─────────> ◉ 💥 (arrival burst)
    4. ✅ ─────────> ◉ ✨ (new node glows)
```

### 3. Confetti & Celebration Effects 🎉

```dart
/// lib/widgets/journey_celebrations.dart

// Using confetti_widget package
class JourneyCelebration extends StatelessWidget {
  final CelebrationType type;
  
  // Celebration types with different intensity:
  // - stepCompleted: Moderate confetti (2 seconds)
  // - milestoneReached: Big confetti + sound (3 seconds)
  // - journeyCompleted: EPIC celebration (5 seconds)
}

enum CelebrationType {
  stepCompleted,      // ✅ Single step done
  milestone25,        // 🎯 25% complete
  milestone50,        // 🎯 50% complete  
  milestone75,        // 🎯 75% complete
  journeyCompleted,   // 🏆 GOAL REACHED!
}

// Celebration effects by type:
Map<CelebrationType, CelebrationConfig> celebrations = {
  CelebrationType.stepCompleted: CelebrationConfig(
    confettiCount: 50,
    duration: Duration(seconds: 2),
    colors: [Colors.green, Colors.lightGreen],
    showBanner: false,
  ),
  CelebrationType.milestone50: CelebrationConfig(
    confettiCount: 150,
    duration: Duration(seconds: 3),
    colors: [Colors.amber, Colors.orange, Colors.yellow],
    showBanner: true,
    bannerText: "🎉 HALFWAY THERE! 🎉",
  ),
  CelebrationType.journeyCompleted: CelebrationConfig(
    confettiCount: 500,
    duration: Duration(seconds: 5),
    colors: [Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.blue],
    showBanner: true,
    bannerText: "🏆 GOAL ACHIEVED! 🏆",
    playSound: true,
    fullScreenOverlay: true,
  ),
};
```

### 4. Node Unlocking Animation 🔓

When prerequisites are met, the next node "unlocks" with a dramatic effect:

```dart
class NodeUnlockAnimation extends StatefulWidget {
  // Animation sequence (1.5 seconds):
  // 1. Lock icon shatters/dissolves
  // 2. Node expands briefly
  // 3. Color transitions from gray to available color
  // 4. Subtle particle burst
  // 5. Node settles into "available" state
}

// Visual:
// Before: 🔒 (gray, locked)
// During: 💥✨ (shattering lock, particles)
// After:  ○ (blue, available, slight glow)
```

### 5. Path Drawing Animation

When journey is first generated, paths animate drawing themselves:

```dart
class PathDrawAnimation extends StatefulWidget {
  // Paths draw from start to finish like a GPS route
  // Duration: ~3 seconds for full journey
  // Each segment draws sequentially
  // Alternative paths draw simultaneously but fainter
}

// Visual sequence:
// t=0s:   ○ (start node appears)
// t=0.3s: ○──> (path starts drawing)
// t=0.6s: ○────> ○ (first connection complete)
// t=0.9s: ○────> ○──> (continues...)
// ...
// t=3s:   Full journey visible with destination pulsing
```

### 6. Current Position Indicator

The "YOU ARE HERE" indicator is always visible and animated:

```dart
class CurrentPositionMarker extends StatelessWidget {
  // Features:
  // 1. Pulsing glow (continuous)
  // 2. "YOU" label with arrow
  // 3. Slightly elevated (z-index above other nodes)
  // 4. Breathing animation (scale 1.0 -> 1.1 -> 1.0, 2s loop)
}

// Visual:
//     ╭───────╮
//     │  YOU  │
//     │   ↓   │
//     ╰───────╯
//        ◉ ← pulsing glow
```

### 7. Progress Integration with Daily Logs

When user logs daily progress, the map should update automatically:

```dart
class DailyProgressMapUpdater {
  // When progress is logged:
  // 1. Listen to progress_chat completion
  // 2. Analyze if log relates to current journey step
  // 3. If yes, show subtle "progress recorded" animation on node
  // 4. If step is now complete, trigger travel animation
  // 5. Recalculate and update ETA display
  
  void onDailyProgressLogged(ProgressEntry entry) {
    final journey = getCurrentJourney();
    final currentStep = journey.mainPath[journey.currentStepIndex];
    
    // Check if progress relates to current step
    if (_progressRelatesTo(entry, currentStep)) {
      // Add note to step
      addStepNote(currentStep.id, entry.summary);
      
      // Show "logged" indicator
      _showProgressLoggedAnimation(currentStep);
      
      // Check if step should be completed
      if (_shouldCompleteStep(currentStep, entry)) {
        completeStep(currentStep.id);
        // This triggers travel animation automatically
      }
    }
    
    // Always recalculate ETA
    recalculateETA();
  }
}
```

### 8. Streak Integration on Map

Display streak prominently on the journey screen:

```dart
// Top of journey screen, next to ETA:
┌─────────────────────────────────────────────────┐
│  🎯 Become a Software Engineer         [⚙️]    │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━ 35%                │
│  🚀 ~3 months to go    🔥 12 day streak        │ ← Streak display
├─────────────────────────────────────────────────┤

// When streak is active, the journey path has a subtle fire effect
// Streak milestones (7, 14, 30 days) trigger bonus celebrations
```

### 9. Sound Effects (Optional)

```dart
// lib/services/journey_sounds.dart

class JourneySoundEffects {
  static const sounds = {
    'step_complete': 'assets/audio/step_complete.mp3',
    'milestone': 'assets/audio/milestone.mp3',
    'journey_complete': 'assets/audio/victory.mp3',
    'unlock': 'assets/audio/unlock.mp3',
    'travel': 'assets/audio/whoosh.mp3',
  };
  
  // Controlled by settings - can be disabled
  static bool enabled = true;
}
```

---


## 📊 Implementation Phases

### Phase 1: Foundation (Week 1)
- [x] Create data models (Dart + Python)
- [x] Add D1 database tables
- [x] Implement Cloudflare Worker endpoints
- [x] Create basic API endpoints in FastAPI
- [x] Update ApiService with new methods

### Phase 2: AI Integration (Week 2)
- [x] Implement journey generation service
- [x] Implement journey adjustment service
- [x] Test AI prompts and refine
- [x] Add progress integration logic


### Phase 3: UI - Goals Tab (Week 3)
- [x] Create GoalsScreen (empty/active states)
- [x] Build goal card component
- [x] Implement journey generation trigger
- [x] Basic journey display (list view initially)

### Phase 4: UI - Mind Map (Week 4)
- [x] Implement custom node visualization
- [x] Build interactive graph layout
- [x] Add tap interactions and dialogs
- [x] Progress logging dialog

### Phase 5: Adjustments & Polish (Week 5)
- [x] Implement path adjustment bottom sheet
- [x] AI-powered step renaming/reordering
- [x] Animations and micro-interactions
- [x] Edge cases and error handling


### Phase 6: Integration & Testing (Week 6)
- [x] Connect with daily progress logging
- [x] Sync journey with notification profile updates
- [ ] Full integration testing
- [ ] Performance optimization

### Phase 7: Sound Effects Polish (Later - Optional)

> ⚠️ **Ship without sounds first!** All animations work silently. Add sounds as polish.

- [ ] Get sound effects from free resources (see below)
- [ ] Add `audioplayers` package
- [ ] Create `assets/audio/` folder
- [ ] Implement `JourneySoundEffects` service
- [ ] Add sound toggle in Settings

#### 🎵 Where to Get Free Sounds

| Sound Needed | Search For | Best Sites |
|-------------|------------|------------|
| `step_complete.mp3` | "success chime", "level up" | [Mixkit](https://mixkit.co/free-sound-effects/game/), [Pixabay](https://pixabay.com/sound-effects/) |
| `milestone.mp3` | "achievement", "fanfare short" | Mixkit, Pixabay |
| `victory.mp3` | "victory fanfare", "celebration" | Mixkit, [Freesound](https://freesound.org/) |
| `unlock.mp3` | "unlock", "power up" | Pixabay, [Zapsplat](https://www.zapsplat.com/) |
| `whoosh.mp3` | "swoosh", "whoosh" | Mixkit, Freesound |

**Recommended sites (100% free, no attribution):**
- **[Mixkit.co](https://mixkit.co/free-sound-effects/game/)** - Best for game sounds
- **[Pixabay Sound Effects](https://pixabay.com/sound-effects/)** - Wide variety

**Steps when ready:**
```yaml
# 1. Add to pubspec.yaml
dependencies:
  audioplayers: ^5.2.1

flutter:
  assets:
    - assets/audio/
```
```dart
// 2. Enable sounds in journey_sounds.dart
static bool enabled = true;  // Flip this when sounds are added
```

---

## ⚠️ Considerations & Edge Cases

### 1. Goal Changes
- What happens if user changes their primary goal?
- Options: Archive old journey, offer to keep it, or discard

### 2. Multiple Goals
- Currently designed for single primary goal
- Future: Could support multiple journeys

### 3. Offline Support
- Cache journey locally
- Queue updates for when online

### 4. AI Failures
- Fallback to manual step creation
- Graceful error UI

### 5. Very Long Journeys
- Collapse completed sections
- Zoom/pan for large maps

---

## 🔗 Dependencies

### New Packages (Flutter)
```yaml
dependencies:
  graphview: ^1.2.1       # For tree layout algorithms
  confetti_widget: ^0.4.0 # For celebration animations
  audioplayers: ^5.2.1    # For sound effects (optional)
  
  # Already in project (used for animations):
  # flutter's built-in AnimationController, InteractiveViewer
```

### Backend Dependencies
None new - using existing Gemini integration

---

## 📝 Files to Create/Modify

### New Files
```
lib/
├── screens/
│   ├── goals_screen.dart               # NEW - Main goals tab
│   └── goal_journey_screen.dart        # NEW - Detailed journey view
├── widgets/
│   ├── goal_roadmap_widget.dart        # NEW - Mind map visualization (InteractiveViewer)
│   ├── goal_step_node.dart             # NEW - Individual node
│   ├── destination_node.dart           # NEW - Red destination marker
│   ├── goal_progress_dialog.dart       # NEW - Progress logging
│   ├── goal_adjustment_sheet.dart      # NEW - AI adjustment
│   ├── journey_travel_animation.dart   # NEW - Node-to-node travel effect
│   ├── journey_celebrations.dart       # NEW - Confetti & celebrations
│   ├── node_unlock_animation.dart      # NEW - Unlock effect
│   ├── path_draw_animation.dart        # NEW - Initial path drawing
│   └── current_position_marker.dart    # NEW - "YOU ARE HERE" indicator
├── models/
│   └── goal_journey.dart               # NEW - Journey models (includes ETAData)
├── bloc/
│   └── goal_journey_cubit.dart         # NEW - State management
├── services/
│   ├── eta_calculator.dart             # NEW - ETA calculation (no API needed)
│   ├── journey_sounds.dart             # NEW - Sound effects (optional)
│   └── daily_progress_updater.dart     # NEW - Syncs logs with journey

assets/
├── audio/                              # NEW - Sound effects (optional)
│   ├── step_complete.mp3
│   ├── milestone.mp3
│   ├── victory.mp3
│   ├── unlock.mp3
│   └── whoosh.mp3

backend/
├── app/
│   ├── models/
│   │   └── goal_journey.py             # NEW
│   ├── routers/
│   │   └── goal_journey.py             # NEW
│   └── services/
│       ├── journey_generator.py        # NEW
│       └── journey_adjuster.py         # NEW
├── cloudflare/
│   └── usage-store-worker/
│       └── migrations/
│           └── 0004_goal_journeys.sql  # NEW
```

### Modified Files
```
lib/
├── screens/
│   └── main_screen.dart            # Replace UsageHistoryScreen
├── core/
│   └── routes.dart                 # Add new routes
├── services/
│   └── api_service.dart            # Add new endpoints

backend/
├── app/
│   ├── main.py                     # Register new router
│   └── models/
│       └── __init__.py             # Export new models
```

---

## ✅ Success Criteria

### Core Functionality
1. **User can see their goal** displayed prominently on the Goals tab
2. **AI generates relevant steps** for any given goal (5-8 steps with branching options)
3. **Users can log progress** on individual steps
4. **AI adjusts the path** when user describes their current activity
5. **Progress syncs with daily logging** feature automatically

### Game-Like Experience
6. **Pannable/Zoomable Map** - User can drag and pinch to explore the journey
7. **Branching Paths Visible** - Alternative routes shown (grayed out) to emphasize choice
8. **Destination in RED** - Goal at end has pin marker, pulsing beacon, "X steps away"
9. **ETA Display** - Shows estimated time to achievement based on user's pace
10. **Travel Animations** - When step completed, animated transition to next node
11. **Confetti Celebrations** - Step completion, milestones (25/50/75%), journey completion
12. **Node Unlocking Effects** - Dramatic unlock animation when prerequisites met
13. **Current Position Marker** - "YOU ARE HERE" indicator with pulsing glow

### Technical Requirements
14. **The mind map is intuitive** and visually appealing (like a game level select)
15. **The feature works offline** with proper sync
16. **ETA calculation is local** - No API call needed for time estimates
17. **Smooth 60fps animations** - All transitions feel premium

---

## 📚 References

- [graphview Flutter package](https://pub.dev/packages/graphview)
- [Skill Tree UX patterns](https://adriancrook.com/f2p-game-mechanics-skill-trees/)
- [AI Goal Tracking Best Practices](https://magai.co)
- [Gamification in Apps](https://appdesign.ie)

---

*Document created: 2026-01-05*
*Last updated: 2026-01-05*
*Author: Surffyy*
