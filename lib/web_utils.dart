import 'dart:js_interop';

import 'package:web/web.dart' as web;

void suppressContextMenu() {
  web.document.addEventListener(
    'contextmenu',
    ((web.Event event) => event.preventDefault()).toJS,
  );
}

void cleanUrlAfterOAuth() {
  final uri = Uri.parse(web.window.location.href);
  if (uri.queryParameters.containsKey('code') ||
      uri.queryParameters.containsKey('error')) {
    // Remove query params, keep just the origin + path
    final cleanUrl = uri.origin + uri.path;
    web.window.history.replaceState(null, '', cleanUrl);
  }
}

void openUrl(String url) {
  web.window.location.href = url;
}

/// Reloads the page so the browser picks up a newer deploy.
void reloadApp() {
  web.window.location.reload();
}
