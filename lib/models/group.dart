class Group {
  final String id;
  final String name;
  final String createdBy;
  final String inviteCode;
  final String color;
  final String? description;
  final Map<String, dynamic> settings;
  final DateTime createdAt;

  Group({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.inviteCode,
    this.color = '#667eea',
    this.description,
    this.settings = const {},
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Group copyWith({
    String? id,
    String? name,
    String? createdBy,
    String? inviteCode,
    String? color,
    String? description,
    Map<String, dynamic>? settings,
    DateTime? createdAt,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      createdBy: createdBy ?? this.createdBy,
      inviteCode: inviteCode ?? this.inviteCode,
      color: color ?? this.color,
      description: description ?? this.description,
      settings: settings ?? this.settings,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'] as String,
      name: json['name'] as String,
      createdBy: json['created_by'] as String,
      inviteCode: json['invite_code'] as String,
      color: json['color'] as String? ?? '#667eea',
      description: json['description'] as String?,
      settings: json['settings'] != null
          ? Map<String, dynamic>.from(json['settings'] as Map)
          : {},
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'created_by': createdBy,
      'invite_code': inviteCode,
      'color': color,
      'description': description,
      'settings': settings,
    };
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'name': name,
      'created_by': createdBy,
      'color': color,
      'description': description,
      'settings': settings,
    };
  }
}
