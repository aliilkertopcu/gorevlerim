import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

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
  Future<void> _startRecording() async {
    try {
      if (!await _recorder.hasPermission()) {
        setState(() {
          _errorText = 'Mikrofon izni verilmedi.';
          _phase = _Phase.error;
        });
        return;
      }

      // Pick the best encoder the platform supports (small files, wide support)
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

      _elapsed = 0;
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _elapsed++);
        if (_elapsed >= _maxRecordSeconds) _stopRecording();
      });

      _ampSub?.cancel();
      _ampSub = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 150))
          .listen((a) {
        if (!mounted) return;
        // dBFS: -60 (silence) .. 0 (max)
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

  Future<void> _cancelRecording() async {
    _ticker?.cancel();
    _ampSub?.cancel();
    try {
      final path = await _recorder.stop();
      if (path != null) await deleteRecordedFile(path);
    } catch (_) {}
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
      if (path == null) throw Exception('Kayıt alınamadı');
      final duration = _elapsed;

      if (duration < 1) {
        await deleteRecordedFile(path);
        setState(() => _phase = _Phase.idle);
        return;
      }

      final bytes = await readRecordedFile(path);
      await deleteRecordedFile(path);

      final result = await ref.read(voiceServiceProvider).transcribe(
            audioBytes: bytes,
            mimeType: _mimeType,
            fileName: 'audio.$_fileExt',
            durationSeconds: duration,
            viewDate: ref.read(selectedDateProvider),
            groupId: ref.read(currentGroupProvider)?.id,
            groupName: ref.read(currentGroupProvider)?.name,
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

  // ---------- Save ----------
  Future<void> _saveTasks() async {
    final result = _result;
    if (result == null) return;
    final selected = result.tasks.where((t) => t.selected && t.title.trim().isNotEmpty).toList();
    if (selected.isEmpty) return;

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
      ref.invalidate(tasksStreamProvider);

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${selected.length} görev eklendi 🎤')),
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

  Widget _buildProcessing(BuildContext context, {String label = 'Ses metne çevriliyor ve görevler çıkarılıyor…'}) {
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
    final selectedCount = result.tasks.where((t) => t.selected).length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (result.tasks.isEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Kayıtta görev bulunamadı. Tekrar deneyebilirsin.',
              textAlign: TextAlign.center,
            ),
          ),
        ] else ...[
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
              label: Text(selectedCount == 0 ? 'Ekle' : '$selectedCount görevi ekle'),
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
