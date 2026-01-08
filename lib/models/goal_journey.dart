/// Goal Journey data models for the Goals feature.
///
/// These models represent the user's journey toward their primary goal,
/// including steps, progress tracking, and the gamified map visualization.

import 'dart:ui' show Offset;

/// Status of a journey step
enum StepStatus {
  locked, // Not yet reachable (grayed out on map)
  available, // Can be started (faded, solid outline)
  inProgress, // Currently working on (glowing, pulsing)
  completed, // Finished (filled with checkmark)
  skipped, // User chose different path (crossed out, visible)
  alternative, // Alternative path not taken (grayed, shows choice)
}

/// Type of path in the journey map
enum PathType {
  main, // The chosen/active path
  alternative, // A visible but unchosen path
  completed, // Already traversed path
}

/// Position of a node on the journey map canvas
class MapPosition {
  final double x; // X coordinate on canvas (0.0 - 1.0 normalized)
  final double y; // Y coordinate on canvas (0.0 - 1.0 normalized)
  final int layer; // Depth level in the tree (0 = start, max = destination)

  const MapPosition({required this.x, required this.y, required this.layer});

  factory MapPosition.fromJson(Map<String, dynamic> json) {
    return MapPosition(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      layer: json['layer'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {'x': x, 'y': y, 'layer': layer};
  }

  /// Convert to Offset for rendering
  Offset toOffset(double canvasWidth, double canvasHeight) {
    return Offset(x * canvasWidth, y * canvasHeight);
  }
}

/// Estimated Time of Achievement data
class ETAData {
  final DateTime? estimatedCompletionDate;
  final int totalEstimatedDays;
  final int daysElapsed;
  final int stepsCompleted;
  final double averageDaysPerStep;
  final double velocityScore; // > 1.0 = ahead, 1.0 = on track, < 1.0 = behind
  final String displayText;

  const ETAData({
    this.estimatedCompletionDate,
    required this.totalEstimatedDays,
    required this.daysElapsed,
    required this.stepsCompleted,
    required this.averageDaysPerStep,
    required this.velocityScore,
    required this.displayText,
  });

  factory ETAData.initial() => const ETAData(
    estimatedCompletionDate: null,
    totalEstimatedDays: 0,
    daysElapsed: 0,
    stepsCompleted: 0,
    averageDaysPerStep: 14.0,
    velocityScore: 1.0,
    displayText: 'Calculating...',
  );

  factory ETAData.fromJson(Map<String, dynamic> json) {
    return ETAData(
      estimatedCompletionDate: json['estimated_completion_date'] != null
          ? DateTime.parse(json['estimated_completion_date'] as String)
          : null,
      totalEstimatedDays: json['total_estimated_days'] as int,
      daysElapsed: json['days_elapsed'] as int,
      stepsCompleted: json['steps_completed'] as int,
      averageDaysPerStep: (json['average_days_per_step'] as num).toDouble(),
      velocityScore: (json['velocity_score'] as num).toDouble(),
      displayText: json['display_text'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'estimated_completion_date': estimatedCompletionDate?.toIso8601String(),
      'total_estimated_days': totalEstimatedDays,
      'days_elapsed': daysElapsed,
      'steps_completed': stepsCompleted,
      'average_days_per_step': averageDaysPerStep,
      'velocity_score': velocityScore,
      'display_text': displayText,
    };
  }
}

/// Individual step in the goal journey
class GoalStep {
  final String id;
  final String journeyId;
  final String title;
  final String? customTitle;
  final String description;
  final int order;
  final StepStatus status;
  final List<String> prerequisites;
  final List<String> alternatives;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final List<String> notes;
  final Map<String, dynamic>? metadata;
  final MapPosition position;
  final PathType pathType;
  final int estimatedDays;
  final int? actualDaysSpent;
  final DateTime createdAt;

  const GoalStep({
    required this.id,
    required this.journeyId,
    required this.title,
    this.customTitle,
    required this.description,
    required this.order,
    required this.status,
    this.prerequisites = const [],
    this.alternatives = const [],
    this.startedAt,
    this.completedAt,
    this.notes = const [],
    this.metadata,
    required this.position,
    required this.pathType,
    required this.estimatedDays,
    this.actualDaysSpent,
    required this.createdAt,
  });

  /// Display title (custom if set, otherwise original)
  String get displayTitle => customTitle ?? title;

  /// Whether the step can be interacted with
  bool get isUnlocked =>
      status != StepStatus.locked && status != StepStatus.alternative;

  /// Whether this step is on the main journey path
  bool get isOnMainPath =>
      pathType == PathType.main || pathType == PathType.completed;

  /// Whether this step is the current one
  bool get isCurrent => status == StepStatus.inProgress;

  factory GoalStep.fromJson(Map<String, dynamic> json) {
    return GoalStep(
      id: json['id'] as String,
      journeyId: json['journey_id'] as String,
      title: json['title'] as String,
      customTitle: json['custom_title'] as String?,
      description: json['description'] as String? ?? '',
      order: json['order_index'] as int? ?? json['order'] as int? ?? 0,
      status: StepStatus.values.firstWhere(
        (s) => s.name.toLowerCase() == (json['status'] as String?)?.toLowerCase(),
        orElse: () => StepStatus.locked,
      ),
      prerequisites:
          (json['prerequisites'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      alternatives:
          (json['alternatives'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      notes:
          (json['notes'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          [],
      metadata: json['metadata'] as Map<String, dynamic>?,
      position: json['position'] != null
          ? MapPosition.fromJson(json['position'] as Map<String, dynamic>)
          : MapPosition(
              x: 0.5,
              y: (json['order'] as int? ?? 0) * 0.1,
              layer: json['order'] as int? ?? 0,
            ),
      pathType: PathType.values.firstWhere(
        (p) => p.name == (json['path_type'] as String?)?.toLowerCase(),
        orElse: () => PathType.main,
      ),
      estimatedDays: json['estimated_days'] as int? ?? 14,
      actualDaysSpent: json['actual_days_spent'] as int?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'journey_id': journeyId,
      'title': title,
      'custom_title': customTitle,
      'description': description,
      'order_index': order,
      'status': status.name.toLowerCase(),
      'prerequisites': prerequisites,
      'alternatives': alternatives,
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'notes': notes,
      'metadata': metadata,
      'position': position.toJson(),
      'path_type': pathType.name,
      'estimated_days': estimatedDays,
      'actual_days_spent': actualDaysSpent,
      'created_at': createdAt.toIso8601String(),
    };
  }

  GoalStep copyWith({
    String? id,
    String? journeyId,
    String? title,
    String? customTitle,
    String? description,
    int? order,
    StepStatus? status,
    List<String>? prerequisites,
    List<String>? alternatives,
    DateTime? startedAt,
    DateTime? completedAt,
    List<String>? notes,
    Map<String, dynamic>? metadata,
    MapPosition? position,
    PathType? pathType,
    int? estimatedDays,
    int? actualDaysSpent,
    DateTime? createdAt,
  }) {
    return GoalStep(
      id: id ?? this.id,
      journeyId: journeyId ?? this.journeyId,
      title: title ?? this.title,
      customTitle: customTitle ?? this.customTitle,
      description: description ?? this.description,
      order: order ?? this.order,
      status: status ?? this.status,
      prerequisites: prerequisites ?? this.prerequisites,
      alternatives: alternatives ?? this.alternatives,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      notes: notes ?? this.notes,
      metadata: metadata ?? this.metadata,
      position: position ?? this.position,
      pathType: pathType ?? this.pathType,
      estimatedDays: estimatedDays ?? this.estimatedDays,
      actualDaysSpent: actualDaysSpent ?? this.actualDaysSpent,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'GoalStep(id: $id, title: $displayTitle, status: $status, order: $order)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GoalStep && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Complete goal journey with all steps and metadata
class GoalJourney {
  final String id;
  final String userId;
  final String? goalId;
  final String goalContent; // The destination - user's main goal
  final String? goalReason;
  final List<GoalStep> steps;
  final int currentStepIndex;
  final double overallProgress; // 0.0 to 1.0
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime journeyStartedAt;
  final bool isAIGenerated;
  final String? aiNotes;
  final double mapWidth;
  final double mapHeight;

  const GoalJourney({
    required this.id,
    required this.userId,
    this.goalId,
    required this.goalContent,
    this.goalReason,
    required this.steps,
    required this.currentStepIndex,
    required this.overallProgress,
    required this.createdAt,
    this.updatedAt,
    required this.journeyStartedAt,
    required this.isAIGenerated,
    this.aiNotes,
    this.mapWidth = 1000.0,
    this.mapHeight = 2000.0,
  });

  /// Get only the main path steps (excluding alternatives)
  List<GoalStep> get mainPath =>
      steps.where((s) => s.isOnMainPath).toList()
        ..sort((a, b) => a.order.compareTo(b.order));

  /// Get the current active step
  GoalStep? get currentStep {
    if (currentStepIndex >= 0 && currentStepIndex < mainPath.length) {
      return mainPath[currentStepIndex];
    }
    return mainPath.firstWhere(
      (s) => s.status == StepStatus.inProgress,
      orElse: () => mainPath.firstWhere(
        (s) => s.status == StepStatus.available,
        orElse: () => mainPath.first,
      ),
    );
  }

  /// Get completed steps
  List<GoalStep> get completedSteps =>
      mainPath.where((s) => s.status == StepStatus.completed).toList();

  /// Get remaining steps
  List<GoalStep> get remainingSteps => mainPath
      .where(
        (s) =>
            s.status != StepStatus.completed && s.status != StepStatus.skipped,
      )
      .toList();

  /// Steps until destination
  int get stepsToDestination => remainingSteps.length;

  /// Is journey complete?
  bool get isComplete => overallProgress >= 1.0 || remainingSteps.isEmpty;

  factory GoalJourney.fromJson(Map<String, dynamic> json) {
    final stepsJson = json['steps'] as List<dynamic>? ?? [];
    return GoalJourney(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      goalId: json['goal_id'] as String?,
      goalContent: json['goal_content'] as String,
      goalReason: json['goal_reason'] as String?,
      steps: stepsJson
          .map((s) => GoalStep.fromJson(s as Map<String, dynamic>))
          .toList(),
      currentStepIndex: json['current_step_index'] as int? ?? 0,
      overallProgress: (json['overall_progress'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      journeyStartedAt: json['journey_started_at'] != null
          ? DateTime.parse(json['journey_started_at'] as String)
          : DateTime.parse(json['created_at'] as String),
      isAIGenerated: json['is_ai_generated'] as bool? ?? true,
      aiNotes: json['ai_notes'] as String?,
      mapWidth: (json['map_width'] as num?)?.toDouble() ?? 1000.0,
      mapHeight: (json['map_height'] as num?)?.toDouble() ?? 2000.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'goal_id': goalId,
      'goal_content': goalContent,
      'goal_reason': goalReason,
      'steps': steps.map((s) => s.toJson()).toList(),
      'current_step_index': currentStepIndex,
      'overall_progress': overallProgress,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'journey_started_at': journeyStartedAt.toIso8601String(),
      'is_ai_generated': isAIGenerated,
      'ai_notes': aiNotes,
      'map_width': mapWidth,
      'map_height': mapHeight,
    };
  }

  GoalJourney copyWith({
    String? id,
    String? userId,
    String? goalId,
    String? goalContent,
    String? goalReason,
    List<GoalStep>? steps,
    int? currentStepIndex,
    double? overallProgress,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? journeyStartedAt,
    bool? isAIGenerated,
    String? aiNotes,
    double? mapWidth,
    double? mapHeight,
  }) {
    return GoalJourney(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      goalId: goalId ?? this.goalId,
      goalContent: goalContent ?? this.goalContent,
      goalReason: goalReason ?? this.goalReason,
      steps: steps ?? this.steps,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      overallProgress: overallProgress ?? this.overallProgress,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      journeyStartedAt: journeyStartedAt ?? this.journeyStartedAt,
      isAIGenerated: isAIGenerated ?? this.isAIGenerated,
      aiNotes: aiNotes ?? this.aiNotes,
      mapWidth: mapWidth ?? this.mapWidth,
      mapHeight: mapHeight ?? this.mapHeight,
    );
  }

  @override
  String toString() {
    return 'GoalJourney(id: $id, goal: $goalContent, progress: ${(overallProgress * 100).toInt()}%, steps: ${steps.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GoalJourney && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Request model for journey adjustment
class JourneyAdjustmentRequest {
  final String journeyId;
  final String currentActivity;
  final String? additionalContext;

  const JourneyAdjustmentRequest({
    required this.journeyId,
    required this.currentActivity,
    this.additionalContext,
  });

  Map<String, dynamic> toJson() {
    return {
      'journey_id': journeyId,
      'current_activity': currentActivity,
      'additional_context': additionalContext,
    };
  }
}

/// Response model for journey adjustment
class JourneyAdjustmentResponse {
  final GoalJourney journey;
  final List<String> changesMade;
  final String aiMessage;

  const JourneyAdjustmentResponse({
    required this.journey,
    required this.changesMade,
    required this.aiMessage,
  });

  factory JourneyAdjustmentResponse.fromJson(Map<String, dynamic> json) {
    return JourneyAdjustmentResponse(
      journey: GoalJourney.fromJson(json['journey'] as Map<String, dynamic>),
      changesMade: (json['changes_made'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      aiMessage: json['ai_message'] as String,
    );
  }
}
