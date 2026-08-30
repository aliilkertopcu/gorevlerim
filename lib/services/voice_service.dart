import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// One task proposed by the AI from a voice recording.
class VoiceTaskProposal {
  String title;
  String description;
  DateTime date;
  List<String> subtasks;
  bool selected;

  VoiceTaskProposal({
    required this.title,
    required this.description,
    required this.date,
    required this.subtasks,
    this.selected = true,
  });

  factory VoiceTaskProposal.fromJson(Map<String, dynamic> json, DateTime fallbackDate) {
    return VoiceTaskProposal(
      title: (json['title'] as String? ?? '').trim(),
      description: (json['description'] as String? ?? '').trim(),
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? fallbackDate,
      subtasks: (json['subtasks'] as List<dynamic>? ?? [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList(),
    );
  }
}

/// A proposed change to an existing task (complete / postpone / delete ...).
class VoiceActionProposal {
  final String type; // complete | uncomplete | postpone | delete | complete_subtask
  final String taskId;
  final String subtaskId;
  final DateTime? targetDate;
  final String title;
  final String? subtaskTitle;
  bool selected;

  VoiceActionProposal({
    required this.type,
    required this.taskId,
    required this.subtaskId,
    required this.targetDate,
    required this.title,
    this.subtaskTitle,
    this.selected = true,
  });

  factory VoiceActionProposal.fromJson(Map<String, dynamic> json) {
    return VoiceActionProposal(
      type: json['type'] as String? ?? '',
      taskId: json['task_id'] as String? ?? '',
      subtaskId: json['subtask_id'] as String? ?? '',
      targetDate: DateTime.tryParse(json['target_date'] as String? ?? ''),
      title: json['title'] as String? ?? '',
      subtaskTitle: json['subtask_title'] as String?,
    );
  }

  String get label {
    switch (type) {
      case 'complete':
        return 'Tamamla: $title';
      case 'uncomplete':
        return 'Geri al: $title';
      case 'postpone':
        return 'Ertele: $title';
      case 'delete':
        return 'Sil: $title';
      case 'complete_subtask':
        return 'Alt görevi tamamla: ${subtaskTitle ?? ''} ($title)';
    }
    return '$type: $title';
  }
}

class VoiceResult {
  final String transcript;
  final List<VoiceTaskProposal> tasks;
  final List<VoiceActionProposal> actions;
  final List<String> ignored;
  final int usedSeconds;
  final int limitSeconds;
  final String? message;

  const VoiceResult({
    required this.transcript,
    required this.tasks,
    this.actions = const [],
    required this.ignored,
    required this.usedSeconds,
    required this.limitSeconds,
    this.message,
  });
}

class VoiceHistoryItem {
  final String id;
  final DateTime createdAt;
  final int durationSeconds;
  final String transcript;
  final List<String> taskTitles;

  const VoiceHistoryItem({
    required this.id,
    required this.createdAt,
    required this.durationSeconds,
    required this.transcript,
    required this.taskTitles,
  });

  factory VoiceHistoryItem.fromJson(Map<String, dynamic> json) {
    final proposal = json['proposal'] as Map<String, dynamic>? ?? {};
    final tasks = proposal['tasks'] as List<dynamic>? ?? [];
    return VoiceHistoryItem(
      id: json['id'] as String,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      durationSeconds: json['duration_seconds'] as int? ?? 0,
      transcript: json['transcript'] as String? ?? '',
      taskTitles: tasks
          .map((t) => (t as Map<String, dynamic>)['title']?.toString() ?? '')
          .where((t) => t.isNotEmpty)
          .toList(),
    );
  }
}

class VoiceQuota {
  final int usedSeconds;
  final int limitSeconds;
  const VoiceQuota({required this.usedSeconds, required this.limitSeconds});
  int get remainingSeconds => (limitSeconds - usedSeconds).clamp(0, limitSeconds);
}

class VoiceQuotaExceeded implements Exception {
  final String message;
  final int usedSeconds;
  final int limitSeconds;
  const VoiceQuotaExceeded(this.message, this.usedSeconds, this.limitSeconds);
  @override
  String toString() => message;
}

/// Client for the `voice-to-tasks` edge function.
class VoiceService {
  final SupabaseClient _client;
  final String _baseUrl;

  VoiceService(this._client, String supabaseUrl) : _baseUrl = supabaseUrl;

  Uri get _endpoint => Uri.parse('$_baseUrl/functions/v1/voice-to-tasks');

  String? get _token => _client.auth.currentSession?.accessToken;

  Future<VoiceQuota> fetchQuota() async {
    final token = _token;
    if (token == null) throw Exception('Oturum bulunamadı');
    final res = await http.post(
      _endpoint.replace(queryParameters: {'status': '1'}),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 15));
    final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(json['error'] ?? 'Kota sorgulanamadı');
    }
    return VoiceQuota(
      usedSeconds: json['used_seconds'] as int? ?? 0,
      limitSeconds: json['limit_seconds'] as int? ?? 600,
    );
  }

  Future<VoiceResult> transcribe({
    required Uint8List audioBytes,
    required String mimeType,
    required String fileName,
    required int durationSeconds,
    required DateTime viewDate,
    String? groupId,
    String? groupName,
    String? contextTasksJson,
  }) async {
    final token = _token;
    if (token == null) throw Exception('Oturum bulunamadı');

    final req = http.MultipartRequest('POST', _endpoint)
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['duration_seconds'] = durationSeconds.toString()
      ..fields['date'] = _dateKey(viewDate)
      ..fields['group_id'] = groupId ?? ''
      ..fields['group_name'] = groupName ?? ''
      ..fields['context_tasks'] = contextTasksJson ?? ''
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        audioBytes,
        filename: fileName,
        contentType: MediaType.parse(mimeType),
      ));

    final streamed = await req.send().timeout(const Duration(seconds: 90));
    final res = await http.Response.fromStream(streamed);
    final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

    if (res.statusCode == 429) {
      throw VoiceQuotaExceeded(
        json['message'] as String? ?? 'Günlük ses limiti doldu',
        json['used_seconds'] as int? ?? 0,
        json['limit_seconds'] as int? ?? 600,
      );
    }
    if (res.statusCode != 200) {
      throw Exception(json['error'] ?? 'Ses işlenemedi (${res.statusCode})');
    }

    return VoiceResult(
      transcript: json['transcript'] as String? ?? '',
      tasks: (json['tasks'] as List<dynamic>? ?? [])
          .map((t) => VoiceTaskProposal.fromJson(t as Map<String, dynamic>, viewDate))
          .where((t) => t.title.isNotEmpty)
          .toList(),
      actions: (json['actions'] as List<dynamic>? ?? [])
          .map((a) => VoiceActionProposal.fromJson(a as Map<String, dynamic>))
          .where((a) => a.taskId.isNotEmpty)
          .toList(),
      ignored: (json['ignored'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      usedSeconds: json['used_seconds'] as int? ?? 0,
      limitSeconds: json['limit_seconds'] as int? ?? 600,
      message: json['message'] as String?,
    );
  }

  Future<List<VoiceHistoryItem>> fetchHistory() async {
    final token = _token;
    if (token == null) throw Exception('Oturum bulunamadı');
    final res = await http.post(
      _endpoint.replace(queryParameters: {'history': '1'}),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 20));
    final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(json['error'] ?? 'Geçmiş alınamadı');
    }
    return (json['items'] as List<dynamic>? ?? [])
        .map((e) => VoiceHistoryItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
