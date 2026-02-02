class Group {
  final String id;
  final String name;
  final String createdBy;
  final String inviteCode;
  final String color;
  final DateTime createdAt;

  Group({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.inviteCode,
    this.color = '#667eea',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Group copyWith({
    String? id,
    String? name,
    String? createdBy,
    String? inviteCode,
    String? color,
    DateTime? createdAt,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      createdBy: createdBy ?? this.createdBy,
      inviteCode: inviteCode ?? this.inviteCode,
      color: color ?? this.color,
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
    };
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'name': name,
      'created_by': createdBy,
      'color': color,
    };
  }
}
