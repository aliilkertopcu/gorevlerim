import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../models/task.dart';
import '../providers/auth_provider.dart';
import '../providers/group_provider.dart';
import '../providers/task_provider.dart';
import '../providers/voice_provider.dart';
import '../services/voice_file_web.dart'
    if (dart.library.io) '../services/voice_file_io.dart';
import '../services/voice_service.dart';
import '../theme/animation_constants.dart';
import 'desktop_dialog.dart';

/// Opens the "Sesle Görev Ekle" flow: record → transcribe → preview → save.
Future<void> showVoiceTaskDialog(BuildContext context) {
  return showAppDialog(
    context: context,
    title: const Row(
      children: [
        Icon(Icons.mic, size: 22),
        SizedBox(width: 8),
        Text('Sesle Görev Ekle'),
      ],
    ),
    content: const VoiceTaskDialog(),
    actions: const [],
    initialWidth: 520,
    minHeight: 260,
  );
}

enum _Phase { loading, idle, recording, processing, preview, saving, quotaExceeded, error }

class VoiceTaskDialog extends ConsumerStatefulWidget {
  const VoiceTaskDialog({super.key});

  @override
  ConsumerState<VoiceTaskDialog> createState() => _VoiceTaskDialogState();
}

class _VoiceTaskDialogState extends ConsumerState<VoiceTaskDialog> {
  static const _maxClipSeconds = 600;

  final _recorder = AudioRecorder();
  _Phase _phase = _Phase.loading;
  String? _errorText;

  VoiceQuota? _quota;
  int _elapsed = 0;
  Timer? _ticker;
  double _amplitude = 0; // 0..1
  StreamSubscription<Amplitude>? _ampSub;

  String _mimeType = 'audio/webm';
  String _fileExt = 'webm';

  VoiceResult? _result;
  bool _showTranscript = false;
  bool _showIgnored = false;

  bool _showHistory = false;
  List<VoiceHistoryItem>? _history;
  String? _historyError;

  Future<void> _toggleHistory() async {
    setState(() => _showHistory = !_showHistory);
    if (_showHistory && _history == null) {
      try {
        final items = await ref.read(voiceServiceProvider).fetchHistory();
        if (!mounted) return;
        setState(() => _history = items);
      } catch (e) {
        if (!mounted) return;
        setState(() => _historyError = e.toString());
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadQuota();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ampSub?.cancel();
    _pcmSub?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  // ---------- Quota ----------
  Future<void> _loadQuota() async {
    try {
      final q = await ref.read(voiceServiceProvider).fetchQuota();
      if (!mounted) return;
      setState(() {
        _quota = q;
        _phase = q.remainingSeconds <= 0 ? _Phase.quotaExceeded : _Phase.idle;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Kota bilgisi alınamadı: $e';
        _phase = _Phase.error;
      });
    }
  }

  int get _maxRecordSeconds {
    final remaining = _quota?.remainingSeconds ?? _maxClipSeconds;
    return remaining.clamp(0, _maxClipSeconds);
  }

  // ---------- Recording ----------
  // Preferred path: PCM stream → 30 s WAV segments transcribed live while the
  // user keeps talking; stop = one short LLM call. Falls back to file recording
  // where streaming is unsupported.
  static const _segmentSeconds = 30;
  static const _sampleRate = 16000;

  bool _streaming = false;
  StreamSubscription<Uint8List>? _pcmSub;
  final BytesBuilder _allPcm = BytesBuilder(copy: false);
  final BytesBuilder _segPcm = BytesBuilder(copy: false);
  int _segStartElapsed = 0;
  int _detectedRate = _sampleRate; // browsers may ignore the requested rate
  DateTime? _streamStartedAt;
  final List<String?> _liveParts = [];
  final List<Future<void>> _pendingPartials = [];
  String? _liveError;

  String get _liveText => _liveParts.whereType<String>().join(' ').trim();
  bool get _hasPendingPartial => _liveParts.contains(null);

  Future<void> _startRecording() async {
    try {
      if (!await _recorder.hasPermission()) {
        setState(() {
          _errorText = 'Mikrofon izni verilmedi.';
          _phase = _Phase.error;
        });
        return;
      }

      _elapsed = 0;
      _segStartElapsed = 0;
      _allPcm.clear();
      _segPcm.clear();
      _liveParts.clear();
      _pendingPartials.clear();
      _liveError = null;

      var started = false;
      try {
        final stream = await _recorder.startStream(const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _sampleRate,
          numChannels: 1,
          noiseSuppress: true,
          echoCancel: true,
          autoGain: true,
        ));
        _streamStartedAt = DateTime.now();
        _pcmSub = stream.listen((chunk) {
          _allPcm.add(chunk);
          _segPcm.add(chunk);
        });
        _streaming = true;
        started = true;
      } catch (_) {
        _streaming = false;
      }
      if (!started) await _startFileRecording();

      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _elapsed++);
        if (_streaming && _elapsed - _segStartElapsed >= _segmentSeconds) _flushSegment();
        if (_elapsed >= _maxRecordSeconds) _stopRecording();
      });

      _ampSub?.cancel();
      _ampSub = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 150))
          .listen((a) {
        if (!mounted) return;
        final norm = ((a.current + 60) / 60).clamp(0.0, 1.0);
        setState(() => _amplitude = norm);
      });

      setState(() => _phase = _Phase.recording);
    } catch (e) {
      setState(() {
        _errorText = 'Kayıt başlatılamadı: $e';
        _phase = _Phase.error;
      });
    }
  }

  /// Legacy path: encoded file on disk / blob, transcribed in one go on stop.
  Future<void> _startFileRecording() async {
    AudioEncoder encoder;
    if (await _recorder.isEncoderSupported(AudioEncoder.opus)) {
      encoder = AudioEncoder.opus;
      _mimeType = kIsWeb ? 'audio/webm' : 'audio/ogg';
      _fileExt = kIsWeb ? 'webm' : 'ogg';
    } else if (await _recorder.isEncoderSupported(AudioEncoder.aacLc)) {
      encoder = AudioEncoder.aacLc;
      _mimeType = 'audio/mp4';
      _fileExt = 'm4a';
    } else {
      encoder = AudioEncoder.wav;
      _mimeType = 'audio/wav';
      _fileExt = 'wav';
    }
    final config = RecordConfig(
      encoder: encoder,
      bitRate: 32000,
      sampleRate: 16000,
      numChannels: 1,
      noiseSuppress: true,
      echoCancel: true,
    );
    String path = '';
    if (!kIsWeb) {
      final dir = await getTemporaryDirectory();
      path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.$_fileExt';
    }
    await _recorder.start(config, path: path);
  }

  /// Measure the real PCM rate from bytes received so far (snap to a standard rate).
  void _updateDetectedRate() {
    final started = _streamStartedAt;
    if (started == null) return;
    final secs = DateTime.now().difference(started).inMilliseconds / 1000.0;
    if (secs < 3) return;
    final raw = _allPcm.length / 2 / secs;
    const rates = [8000, 16000, 22050, 24000, 32000, 44100, 48000];
    var best = rates.first;
    for (final r in rates) {
      if ((r - raw).abs() < (best - raw).abs()) best = r;
    }
    _detectedRate = best;
  }

  /// Send the current PCM segment for live transcription.
  void _flushSegment() {
    _updateDetectedRate();
    final bytes = _segPcm.takeBytes();
    _segStartElapsed = _elapsed;
    if (bytes.length < _detectedRate) return; // < 0.5 s, skip
    final slot = _liveParts.length;
    _liveParts.add(null);
    final prev = _liveText;
    final duration = (bytes.length / (_detectedRate * 2)).ceil();
    final f = ref
        .read(voiceServiceProvider)
        .transcribePartial(
          wavBytes: _pcmToWav(bytes, _detectedRate),
          durationSeconds: duration,
          prevText: prev,
          groupId: ref.read(currentGroupProvider)?.id,
        )
        .then((r) {
      if (!mounted) return;
      setState(() {
        _liveParts[slot] = r.text;
        _quota = VoiceQuota(usedSeconds: r.usedSeconds, limitSeconds: r.limitSeconds);
      });
    }).catchError((e) {
      if (!mounted) return;
      setState(() {
        _liveParts[slot] = '';
        if (e is VoiceQuotaExceeded) {
          _quota = VoiceQuota(usedSeconds: e.usedSeconds, limitSeconds: e.limitSeconds);
          _liveError = e.message;
          if (_phase == _Phase.recording) _stopRecording();
        } else {
          _liveError = 'Bir parça çevrilemedi: $e';
        }
      });
    });
    _pendingPartials.add(f);
    setState(() {});
  }

  Future<void> _cancelRecording() async {
    _ticker?.cancel();
    _ampSub?.cancel();
    try {
      final path = await _recorder.stop();
      await _pcmSub?.cancel();
      _pcmSub = null;
      if (!_streaming && path != null) await deleteRecordedFile(path);
    } catch (_) {}
    _allPcm.clear();
    _segPcm.clear();
    _liveParts.clear();
    if (!mounted) return;
    setState(() {
      _phase = _Phase.idle;
      _elapsed = 0;
      _amplitude = 0;
    });
  }

  Future<void> _stopRecording() async {
    if (_phase != _Phase.recording) return;
    _ticker?.cancel();
    _ampSub?.cancel();
    setState(() => _phase = _Phase.processing);

    try {
      final path = await _recorder.stop();
      await _pcmSub?.cancel();
      _pcmSub = null;
      final duration = _elapsed;

      if (duration < 1) {
        if (!_streaming && path != null) await deleteRecordedFile(path);
        setState(() => _phase = _Phase.idle);
        return;
      }

      final Uint8List bytes;
      final String mime;
      final String fileName;
      String? override;
      if (_streaming) {
        _flushSegment();
        await Future.wait(_pendingPartials);
        _updateDetectedRate();
        bytes = _pcmToWav(_allPcm.takeBytes(), _detectedRate);
        mime = 'audio/wav';
        fileName = 'audio.wav';
        override = _liveText;
        if (override.isEmpty) {
          if (!mounted) return;
          setState(() {
            _result = VoiceResult(
              transcript: '',
              tasks: const [],
              ignored: const [],
              usedSeconds: _quota?.usedSeconds ?? 0,
              limitSeconds: _quota?.limitSeconds ?? 600,
              message: 'Kayıtta konuşma algılanamadı.',
            );
            _phase = _Phase.preview;
          });
          return;
        }
      } else {
        if (path == null) throw Exception('Kayıt alınamadı');
        bytes = await readRecordedFile(path);
        await deleteRecordedFile(path);
        mime = _mimeType;
        fileName = 'audio.$_fileExt';
      }

      final result = await ref.read(voiceServiceProvider).transcribe(
            audioBytes: bytes,
            mimeType: mime,
            fileName: fileName,
            durationSeconds: duration,
            viewDate: ref.read(selectedDateProvider),
            groupId: ref.read(currentGroupProvider)?.id,
            groupName: ref.read(currentGroupProvider)?.name,
            contextTasksJson: _contextTasksJson(),
            transcriptOverride: override,
            sttMode: _streaming ? 'stream' : null,
          );

      if (!mounted) return;
      ref.invalidate(voiceQuotaProvider);
      setState(() {
        _result = result;
        _quota = VoiceQuota(usedSeconds: result.usedSeconds, limitSeconds: result.limitSeconds);
        _phase = _Phase.preview;
      });
    } on VoiceQuotaExceeded catch (e) {
      if (!mounted) return;
      setState(() {
        _quota = VoiceQuota(usedSeconds: e.usedSeconds, limitSeconds: e.limitSeconds);
        _phase = _Phase.quotaExceeded;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Ses işlenemedi: $e';
        _phase = _Phase.error;
      });
    }
  }

  /// Wrap raw 16-bit mono PCM in a WAV container.
  static Uint8List _pcmToWav(Uint8List pcm, int sampleRate) {
    const channels = 1;
    const bitsPerSample = 16;
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final out = ByteData(44 + pcm.length);
    void str(int o, String s) {
      for (var i = 0; i < s.length; i++) {
        out.setUint8(o + i, s.codeUnitAt(i));
      }
    }
    str(0, 'RIFF');
    out.setUint32(4, 36 + pcm.length, Endian.little);
    str(8, 'WAVE');
    str(12, 'fmt ');
    out.setUint32(16, 16, Endian.little);
    out.setUint16(20, 1, Endian.little);
    out.setUint16(22, channels, Endian.little);
    out.setUint32(24, sampleRate, Endian.little);
    out.setUint32(28, byteRate, Endian.little);
    out.setUint16(32, channels * bitsPerSample ~/ 8, Endian.little);
    out.setUint16(34, bitsPerSample, Endian.little);
    str(36, 'data');
    out.setUint32(40, pcm.length, Endian.little);
    out.buffer.asUint8List(44).setAll(0, pcm);
    return out.buffer.asUint8List();
  }

  /// Current day's tasks as compact JSON so the model can act on existing items.
  String _contextTasksJson() {
    final tasks = ref.read(tasksProvider).value ?? const <Task>[];
    final list = tasks.take(60).map((t) => {
          'id': t.id,
          'title': t.title,
          'status': t.status,
          'date': '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}-${t.date.day.toString().padLeft(2, '0')}',
          'subtasks': t.subtasks
              .take(20)
              .map((s) => {'id': s.id, 'title': s.title, 'status': s.status})
              .toList(),
        }).toList();
    return jsonEncode(list);
  }

  Future<void> _applyActions(List<VoiceActionProposal> actions) async {
    final service = ref.read(taskServiceProvider);
    final notifier = ref.read(tasksNotifierProvider.notifier);
    final tasks = ref.read(tasksProvider).value ?? const <Task>[];
    for (final a in actions) {
      final task = tasks.where((t) => t.id == a.taskId).firstOrNull;
      switch (a.type) {
        case 'complete':
          if (task != null && !task.isCompleted) {
            notifier.optimisticToggleComplete(a.taskId);
            await service.toggleComplete(a.taskId, false);
          }
          break;
        case 'uncomplete':
          if (task != null && task.isCompleted) {
            notifier.optimisticToggleComplete(a.taskId);
            await service.toggleComplete(a.taskId, true);
          }
          break;
        case 'postpone':
          if (a.targetDate != null) await service.postponeTask(a.taskId, a.targetDate!);
          break;
        case 'delete':
          notifier.optimisticDeleteTask(a.taskId);
          await service.deleteTask(a.taskId);
          break;
        case 'complete_subtask':
          final sub = task?.subtasks.where((s) => s.id == a.subtaskId).firstOrNull;
          if (sub != null && !sub.isCompleted) {
            notifier.optimisticToggleSubtask(a.taskId, a.subtaskId);
            await service.toggleSubtaskComplete(a.subtaskId, false);
          }
          break;
      }
    }
  }

  // ---------- Save ----------
  Future<void> _saveTasks() async {
    final result = _result;
    if (result == null) return;
    final selected = result.tasks.where((t) => t.selected && t.title.trim().isNotEmpty).toList();
    final selectedActions = result.actions.where((a) => a.selected).toList();
    if (selected.isEmpty && selectedActions.isEmpty) return;

    final owner = ref.read(ownerContextProvider);
    final user = ref.read(currentUserProvider);
    if (owner == null || user == null) return;

    setState(() => _phase = _Phase.saving);

    try {
      final taskService = ref.read(taskServiceProvider);
      for (final t in selected) {
        await taskService.createTask(
          ownerId: owner.ownerId,
          ownerType: owner.ownerType,
          date: t.date,
          title: t.title.trim(),
          description: t.description.trim().isEmpty ? null : t.description.trim(),
          createdBy: user.id,
          subtaskTitles: t.subtasks,
        );
        if (owner.ownerType == 'group') {
          ref.read(groupServiceProvider).logActivity(
                groupId: owner.ownerId,
                userId: user.id,
                action: 'task_created',
                details: '"${t.title.trim()}" (sesle)',
              );
        }
      }
      await _applyActions(selectedActions);
      refreshTasks(ref);

      if (!mounted) return;
      Navigator.of(context).pop();
      final parts = <String>[
        if (selected.isNotEmpty) '${selected.length} görev eklendi',
        if (selectedActions.isNotEmpty) '${selectedActions.length} değişiklik uygulandı',
      ];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${parts.join(', ')} 🎤')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Görevler kaydedilemedi: $e';
        _phase = _Phase.error;
      });
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Anim.normal,
      switchInCurve: Anim.enterCurve,
      child: KeyedSubtree(key: ValueKey(_phase), child: _buildPhase(context)),
    );
  }

  Widget _buildPhase(BuildContext context) {
    switch (_phase) {
      case _Phase.loading:
        return const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        );
      case _Phase.idle:
        return _buildIdle(context);
      case _Phase.recording:
        return _buildRecording(context);
      case _Phase.processing:
        return _buildProcessing(context);
      case _Phase.preview:
        return _buildPreview(context);
      case _Phase.saving:
        return _buildProcessing(context, label: 'Görevler kaydediliyor…');
      case _Phase.quotaExceeded:
        return _buildQuotaExceeded(context);
      case _Phase.error:
        return _buildError(context);
    }
  }

  String _fmt(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Widget _quotaLine(BuildContext context) {
    final q = _quota;
    if (q == null) return const SizedBox.shrink();
    final remaining = q.remainingSeconds;
    final ratio = q.limitSeconds == 0 ? 0.0 : (q.usedSeconds / q.limitSeconds).clamp(0.0, 1.0);
    final color = ref.watch(currentOwnerColorProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Bugün kalan süre', style: Theme.of(context).textTheme.bodySmall),
            Text(_fmt(remaining), style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 4,
            color: color,
            backgroundColor: color.withValues(alpha: 0.15),
          ),
        ),
      ],
    );
  }

  Widget _buildIdle(BuildContext context) {
    final color = ref.watch(currentOwnerColorProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Konuş, yapay zeka görev ve alt görevlere ayırsın; kaydetmeden önce düzenlersin.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 6),
        Text(
          '"Ana başlık taahhüt işleri, alt görev interneti bağlat. Yarına iş: faturayı yatır."',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 12),
        Center(
          child: _MicButton(
            color: color,
            amplitude: 0,
            recording: false,
            onTap: _startRecording,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Kaydı başlat (en fazla ${_fmt(_maxRecordSeconds)})',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 12),
        _quotaLine(context),
        const SizedBox(height: 8),
        _Expander(
          label: 'Önceki kayıtlar',
          expanded: _showHistory,
          onToggle: _toggleHistory,
          child: _buildHistory(context),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Kapat'),
          ),
        ),
      ],
    );
  }

  Widget _buildHistory(BuildContext context) {
    final theme = Theme.of(context);
    if (_historyError != null) {
      return Text(_historyError!, style: theme.textTheme.bodySmall?.copyWith(color: Colors.red));
    }
    final items = _history;
    if (items == null) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    if (items.isEmpty) {
      return Text('Henüz kayıt yok.', style: theme.textTheme.bodySmall);
    }
    final fmt = DateFormat('d MMM HH:mm', 'tr_TR');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${fmt.format(item.createdAt)} · ${_fmt(item.durationSeconds)} · ${item.taskTitles.length} görev',
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                SelectableText(item.transcript, style: theme.textTheme.bodySmall),
                if (item.taskTitles.isNotEmpty)
                  Text(
                    '→ ${item.taskTitles.join(' · ')}',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildRecording(BuildContext context) {
    final color = ref.watch(currentOwnerColorProvider);
    final remaining = _maxRecordSeconds - _elapsed;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Text(
            _fmt(_elapsed),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: color,
                ),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            remaining <= 30 ? 'Kalan: ${_fmt(remaining)}' : 'Dinliyorum…',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: remaining <= 30 ? Colors.orange : null,
                ),
          ),
        ),
        if (_streaming) ...[
          const SizedBox(height: 10),
          Container(
            constraints: const BoxConstraints(minHeight: 44, maxHeight: 140),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              reverse: true,
              child: Text(
                _liveText.isEmpty
                    ? (_hasPendingPartial ? 'Çevriliyor…' : 'Konuştukça metin burada belirir (30 s aralıklarla).')
                    : '$_liveText${_hasPendingPartial ? ' …' : ''}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _liveText.isEmpty ? Theme.of(context).hintColor : null,
                    ),
              ),
            ),
          ),
          if (_liveError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_liveError!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.orange)),
            ),
        ],
        const SizedBox(height: 12),
        Center(
          child: _MicButton(
            color: Colors.red,
            amplitude: _amplitude,
            recording: true,
            onTap: _stopRecording,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text('Bitirmek için dokun', style: Theme.of(context).textTheme.bodySmall),
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 4,
          children: [
            TextButton(onPressed: _cancelRecording, child: const Text('İptal')),
            ElevatedButton.icon(
              onPressed: _stopRecording,
              icon: const Icon(Icons.stop, size: 18),
              label: const Text('Bitir'),
              style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProcessing(BuildContext context, {String label = 'Görevler çıkarılıyor…'}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildQuotaExceeded(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.hourglass_bottom, size: 40, color: Colors.orange),
        const SizedBox(height: 12),
        const Text(
          'Bugünkü ses kaydı limitin doldu.\nYarın tekrar deneyebilirsin.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        _quotaLine(context),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Kapat'),
          ),
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.error_outline, size: 40, color: Colors.red),
        const SizedBox(height: 12),
        Text(_errorText ?? 'Bir hata oluştu', textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 4,
          children: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Kapat')),
            ElevatedButton(
              onPressed: () {
                setState(() => _phase = _Phase.loading);
                _loadQuota();
              },
              child: const Text('Tekrar dene'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPreview(BuildContext context) {
    final result = _result!;
    final color = ref.watch(currentOwnerColorProvider);
    final selectedCount = result.tasks.where((t) => t.selected).length +
        result.actions.where((a) => a.selected).length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (result.actions.isNotEmpty) ...[
          Text(
            '${result.actions.length} değişiklik — mevcut görevlerde:',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          for (final a in result.actions)
            _ActionTile(
              key: ValueKey('action_${a.type}_${a.taskId}_${a.subtaskId}'),
              action: a,
              color: color,
              onChanged: () => setState(() {}),
            ),
          const SizedBox(height: 8),
        ],
        if (result.tasks.isEmpty && result.actions.isEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Kayıtta görev bulunamadı. Tekrar deneyebilirsin.',
              textAlign: TextAlign.center,
            ),
          ),
        ] else if (result.tasks.isNotEmpty) ...[
          Text(
            '${result.tasks.length} görev bulundu — eklemek istediklerini seç, gerekirse düzenle:',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < result.tasks.length; i++)
            _ProposalTile(
              key: ValueKey('proposal_$i'),
              proposal: result.tasks[i],
              color: color,
              onChanged: () => setState(() {}),
              onRemoveSubtask: (idx) => setState(() => result.tasks[i].subtasks.removeAt(idx)),
            ),
        ],
        const SizedBox(height: 8),
        // Transcript
        _Expander(
          label: 'Metin (${result.transcript.length} karakter)',
          expanded: _showTranscript,
          onToggle: () => setState(() => _showTranscript = !_showTranscript),
          child: SelectableText(
            result.transcript.isEmpty ? '—' : result.transcript,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        if (result.ignored.isNotEmpty)
          _Expander(
            label: 'Görev sayılmayanlar (${result.ignored.length})',
            expanded: _showIgnored,
            onToggle: () => setState(() => _showIgnored = !_showIgnored),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final s in result.ignored)
                  Text('• $s', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        const SizedBox(height: 8),
        _quotaLine(context),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 4,
          children: [
            TextButton(
              onPressed: () => setState(() {
                _result = null;
                _phase = _Phase.idle;
              }),
              child: const Text('Yeniden kaydet'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('İptal'),
            ),
            ElevatedButton.icon(
              onPressed: selectedCount == 0 ? null : _saveTasks,
              icon: const Icon(Icons.check, size: 18),
              label: Text(selectedCount == 0 ? 'Uygula' : '$selectedCount öğeyi uygula'),
              style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------- Sub-widgets ----------

class _MicButton extends StatelessWidget {
  final Color color;
  final double amplitude;
  final bool recording;
  final VoidCallback onTap;

  const _MicButton({
    required this.color,
    required this.amplitude,
    required this.recording,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final haloScale = recording ? 1.0 + amplitude * 0.6 : 1.0;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 96,
        height: 96,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedContainer(
              duration: Anim.fast,
              width: 64 * haloScale,
              height: 64 * haloScale,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: recording ? 0.25 : 0.12),
              ),
            ),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: Icon(recording ? Icons.stop : Icons.mic, color: Colors.white, size: 28),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProposalTile extends StatefulWidget {
  final VoiceTaskProposal proposal;
  final Color color;
  final VoidCallback onChanged;
  final void Function(int index) onRemoveSubtask;

  const _ProposalTile({
    super.key,
    required this.proposal,
    required this.color,
    required this.onChanged,
    required this.onRemoveSubtask,
  });

  @override
  State<_ProposalTile> createState() => _ProposalTileState();
}

class _ProposalTileState extends State<_ProposalTile> {
  late final TextEditingController _titleCtrl;
  static final _dateFmt = DateFormat('d MMM EEE', 'tr_TR');

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.proposal.title);
    _titleCtrl.addListener(() {
      widget.proposal.title = _titleCtrl.text;
      widget.onChanged();
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.proposal.date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      locale: const Locale('tr'),
    );
    if (picked != null) {
      setState(() => widget.proposal.date = picked);
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.proposal;
    final theme = Theme.of(context);
    final muted = !p.selected;

    return AnimatedOpacity(
      duration: Anim.fast,
      opacity: muted ? 0.5 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(4, 4, 8, 8),
        decoration: BoxDecoration(
          border: Border.all(color: widget.color.withValues(alpha: p.selected ? 0.5 : 0.2)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: p.selected,
                  activeColor: widget.color,
                  onChanged: (v) {
                    setState(() => p.selected = v ?? true);
                    widget.onChanged();
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _titleCtrl,
                    enabled: p.selected,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: p.selected ? _pickDate : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event, size: 14, color: widget.color),
                        const SizedBox(width: 4),
                        Text(_dateFmt.format(p.date), style: theme.textTheme.bodySmall, softWrap: false),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (p.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 44, right: 8),
                child: Text(p.description, style: theme.textTheme.bodySmall),
              ),
            if (p.subtasks.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 40, top: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < p.subtasks.length; i++)
                      Row(
                        children: [
                          Icon(Icons.subdirectory_arrow_right, size: 14, color: theme.hintColor),
                          const SizedBox(width: 4),
                          Expanded(child: Text(p.subtasks[i], style: theme.textTheme.bodySmall)),
                          InkWell(
                            onTap: p.selected ? () => widget.onRemoveSubtask(i) : null,
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(Icons.close, size: 14, color: theme.hintColor),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final VoiceActionProposal action;
  final Color color;
  final VoidCallback onChanged;

  const _ActionTile({super.key, required this.action, required this.color, required this.onChanged});

  IconData get _icon {
    switch (action.type) {
      case 'complete':
      case 'complete_subtask':
        return Icons.check_circle_outline;
      case 'uncomplete':
        return Icons.undo;
      case 'postpone':
        return Icons.event;
      case 'delete':
        return Icons.delete_outline;
    }
    return Icons.edit;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFmt = DateFormat('d MMM EEE', 'tr_TR');
    final suffix = action.type == 'postpone' && action.targetDate != null
        ? ' → ${dateFmt.format(action.targetDate!)}'
        : '';
    return AnimatedOpacity(
      duration: Anim.fast,
      opacity: action.selected ? 1 : 0.5,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: action.selected ? 0.08 : 0.03),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Checkbox(
              value: action.selected,
              activeColor: color,
              onChanged: (v) {
                action.selected = v ?? true;
                onChanged();
              },
            ),
            Icon(_icon, size: 18, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${action.label}$suffix',
                style: theme.textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

class _Expander extends StatelessWidget {
  final String label;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  const _Expander({
    required this.label,
    required this.expanded,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 18),
                const SizedBox(width: 4),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: Anim.normal,
          curve: Anim.defaultCurve,
          alignment: Alignment.topCenter,
          child: expanded
              ? Padding(padding: const EdgeInsets.only(left: 22, bottom: 8), child: child)
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
