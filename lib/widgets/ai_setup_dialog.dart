import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_key_service.dart';

final apiKeyServiceProvider = Provider((ref) {
  return ApiKeyService(Supabase.instance.client);
});

class AISetupDialog extends ConsumerStatefulWidget {
  const AISetupDialog({super.key});

  @override
  ConsumerState<AISetupDialog> createState() => _AISetupDialogState();
}

class _AISetupDialogState extends ConsumerState<AISetupDialog> {
  String? _apiKey;
  String? _prompt;
  bool _loading = true;
  bool _copied = false;
  bool _keyCopied = false;
  DateTime? _longPressStart;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final service = ref.read(apiKeyServiceProvider);
    final key = await service.getOrCreateApiKey(userId);
    final prompt = service.generateAIPrompt(key);

    setState(() {
      _apiKey = key;
      _prompt = prompt;
      _loading = false;
    });
  }

  Future<void> _regenerateKey() async {
    setState(() => _loading = true);

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final service = ref.read(apiKeyServiceProvider);
    final key = await service.regenerateApiKey(userId);
    final prompt = service.generateAIPrompt(key);

    setState(() {
      _apiKey = key;
      _prompt = prompt;
      _loading = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API anahtarı yenilendi')),
      );
    }
  }

  void _copyApiKey() {
    if (_apiKey == null) return;
    Clipboard.setData(ClipboardData(text: _apiKey!));
    setState(() => _keyCopied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _keyCopied = false);
    });
  }

  Future<void> _confirmRegenerate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('API Anahtarını Yenile'),
        content: const Text(
          'Mevcut anahtarınız geçersiz olacak ve AI entegrasyonlarınızı yeni anahtarla güncellemeniz gerekecek.\n\nDevam etmek istiyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yenile'),
          ),
        ],
      ),
    );
    if (confirmed == true) _regenerateKey();
  }

  void _copyPrompt() {
    if (_prompt == null) return;
    Clipboard.setData(ClipboardData(text: _prompt!));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.smart_toy,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'AI Entegrasyonu',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Instructions
                          Text(
                            'Claude veya ChatGPT ile görev eklemek için:',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildStep('1', 'Aşağıdaki metni kopyala'),
                          _buildStep('2', 'Claude veya ChatGPT uygulamasına yapıştır'),
                          _buildStep('3', 'Artık sesli görev ekleyebilirsin!'),

                          const SizedBox(height: 16),

                          // API Key display
                          GestureDetector(
                            onLongPressStart: (_) {
                              _longPressStart = DateTime.now();
                            },
                            onLongPressEnd: (_) {
                              if (_longPressStart != null) {
                                final held = DateTime.now().difference(_longPressStart!);
                                _longPressStart = null;
                                if (held.inSeconds >= 5) _confirmRegenerate();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.grey[900] : Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.key, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _apiKey ?? '',
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      _keyCopied ? Icons.check : Icons.copy,
                                      size: 18,
                                    ),
                                    onPressed: _copyApiKey,
                                    tooltip: 'API anahtarını kopyala',
                                    color: _keyCopied ? Colors.green : null,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Prompt preview
                          Container(
                            height: 200,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[900] : Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                              ),
                            ),
                            child: SingleChildScrollView(
                              child: Text(
                                _prompt ?? '',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),

            // Footer with copy button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _copyPrompt,
                  icon: Icon(_copied ? Icons.check : Icons.copy),
                  label: Text(_copied ? 'Kopyalandı!' : 'Metni Kopyala'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _copied ? Colors.green : null,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }
}
