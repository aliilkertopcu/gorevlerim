class ChatMessage {
  final String id;
  final String? taskId;
  final String? subtaskId;
  final String userId;
  final String? userName;
  final String content;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    this.taskId,
    this.subtaskId,
    required this.userId,
    this.userName,
    required this.content,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      taskId: json['task_id'] as String?,
      subtaskId: json['subtask_id'] as String?,
      userId: json['user_id'] as String,
      userName: json['user_name'] as String?,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
