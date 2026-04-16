import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connection_provider.dart';

class ConnectionBanner extends ConsumerWidget {
  const ConnectionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionAsync = ref.watch(connectionProvider);

    return connectionAsync.when(
      data: (isOnline) => isOnline ? const SizedBox.shrink() : _Banner(loading: false),
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const _Banner(loading: false),
    );
  }
}

class _Banner extends ConsumerWidget {
  final bool loading;
  const _Banner({required this.loading});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.orange[800],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            loading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.wifi_off, color: Colors.white, size: 16),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Sunucuya bağlanılamıyor',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
            ),
            if (!loading)
              TextButton(
                onPressed: () =>
                    ref.read(connectionProvider.notifier).retry(),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Tekrar Dene',
                    style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }
}
