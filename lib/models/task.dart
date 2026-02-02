class Subtask {
  final String id;
  final String taskId;
  final String title;
  final String status; // pending, completed, blocked
  final String? blockReason;
  final int sortOrder;
  final DateTime createdAt;

  Subtask({
    required this.id,
    required this.taskId,
    required this.title,
    this.status = 'pending',
    this.blockReason,
    this.sortOrder = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isCompleted => status == 'completed';
  bool get isBlocked => status == 'blocked';
  bool get isPending => status == 'pending';

  Subtask copyWith({
    String? id,
    String? taskId,
    String? title,
    String? status,
    String? blockReason,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return Subtask(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      title: title ?? this.title,
      status: status ?? this.status,
      blockReason: blockReason ?? this.blockReason,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Subtask.fromJson(Map<String, dynamic> json) {
    return Subtask(
      id: json['id'] as String,
      taskId: json['task_id'] as String,
      title: json['title'] as String,
      status: json['status'] as String? ?? 'pending',
      blockReason: json['block_reason'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'task_id': taskId,
      'title': title,
      'status': status,
      'block_reason': blockReason,
      'sort_order': sortOrder,
    };
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'task_id': taskId,
      'title': title,
      'status': status,
      'block_reason': blockReason,
      'sort_order': sortOrder,
    };
  }
}

class Task {
  final String id;
  final String ownerId;
  final String ownerType; // 'user' or 'group'
  final DateTime date;
  final String title;
  final String? description;
  final String status; // pending, completed, blocked, postponed
  final String? blockReason;
  final DateTime? postponedTo;
  final int sortOrder;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Subtask> subtasks;

  Task({
    required this.id,
    required this.ownerId,
    required this.ownerType,
    required this.date,
    required this.title,
    this.description,
    this.status = 'pending',
    this.blockReason,
    this.postponedTo,
    this.sortOrder = 0,
    this.createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.subtasks = const [],
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isCompleted => status == 'completed';
  bool get isBlocked => status == 'blocked';
  bool get isPostponed => status == 'postponed';
  bool get isPending => status == 'pending';

  int get completedSubtaskCount =>
      subtasks.where((s) => s.isCompleted).length;

  int get totalSubtaskCount => subtasks.length;

  Task copyWith({
    String? id,
    String? ownerId,
    String? ownerType,
    DateTime? date,
    String? title,
    String? description,
    String? status,
    String? blockReason,
    DateTime? postponedTo,
    int? sortOrder,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Subtask>? subtasks,
  }) {
    return Task(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      ownerType: ownerType ?? this.ownerType,
      date: date ?? this.date,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      blockReason: blockReason ?? this.blockReason,
      postponedTo: postponedTo ?? this.postponedTo,
      sortOrder: sortOrder ?? this.sortOrder,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      subtasks: subtasks ?? this.subtasks,
    );
  }

  factory Task.fromJson(Map<String, dynamic> json, {List<Subtask>? subtasks}) {
    return Task(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      ownerType: json['owner_type'] as String,
      date: DateTime.parse(json['date'] as String),
      title: json['title'] as String,
      description: json['description'] as String?,
      status: json['status'] as String? ?? 'pending',
      blockReason: json['block_reason'] as String?,
      postponedTo: json['postponed_to'] != null
          ? DateTime.parse(json['postponed_to'] as String)
          : null,
      sortOrder: json['sort_order'] as int? ?? 0,
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
      subtasks: subtasks ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner_id': ownerId,
      'owner_type': ownerType,
      'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'title': title,
      'description': description,
      'status': status,
      'block_reason': blockReason,
      'postponed_to': postponedTo != null
          ? '${postponedTo!.year}-${postponedTo!.month.toString().padLeft(2, '0')}-${postponedTo!.day.toString().padLeft(2, '0')}'
          : null,
      'sort_order': sortOrder,
      'created_by': createdBy,
    };
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'owner_id': ownerId,
      'owner_type': ownerType,
      'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'title': title,
      'description': description,
      'status': status,
      'block_reason': blockReason,
      'postponed_to': postponedTo != null
          ? '${postponedTo!.year}-${postponedTo!.month.toString().padLeft(2, '0')}-${postponedTo!.day.toString().padLeft(2, '0')}'
          : null,
      'sort_order': sortOrder,
      'created_by': createdBy,
    };
  }
}
