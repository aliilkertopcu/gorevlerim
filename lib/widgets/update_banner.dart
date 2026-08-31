import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/update_provider.dart';
import '../theme/animation_constants.dart';
import '../theme/app_theme.dart';
import '../web_utils_stub.dart' if (dart.library.js_interop) '../web_utils.dart';

/// Tells a long-open tab that a newer build is waiting, and reloads into it.
class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available = ref.watch(updateAvailableProvider);
    final scheme = Theme.of(context).colorScheme;

    return AnimatedSize(
      duration: Anim.enabled(context) ? Anim.enter : Duration.zero,
      curve: Anim.enterCurve,
      alignment: Alignment.topCenter,
      child: !available
          ? const SizedBox(width: double.infinity)
          : Material(
              color: scheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 16, color: scheme.onPrimaryContainer),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: Text(
                        'Yeni sürüm hazır',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    TextButton(
                      onPressed: reloadApp,
                      style: TextButton.styleFrom(
                        foregroundColor: scheme.onPrimaryContainer,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Yenile'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
