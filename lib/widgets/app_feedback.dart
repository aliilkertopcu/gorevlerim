import 'package:flutter/material.dart';

/// Human-friendly error feedback. Never show raw exception text to users;
/// log it to the console instead and give the user a short, actionable line.
void showErrorSnack(BuildContext context, Object error, {String? message}) {
  debugPrint('UI error: $error');
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      backgroundColor: scheme.errorContainer,
      content: Text(
        message ?? 'İşlem tamamlanamadı. Bağlantını kontrol edip tekrar dener misin?',
        style: TextStyle(color: scheme.onErrorContainer),
      ),
    ));
}

/// Inline (non-snackbar) error line for lists/panels.
String friendlyError(Object error) {
  debugPrint('UI error: $error');
  return 'Yüklenemedi. Bağlantını kontrol edip tekrar dener misin?';
}
