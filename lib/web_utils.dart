import 'dart:html' as html;

void cleanUrlAfterOAuth() {
  final uri = Uri.parse(html.window.location.href);
  if (uri.queryParameters.containsKey('code') ||
      uri.queryParameters.containsKey('error')) {
    // Remove query params, keep just the origin + path
    final cleanUrl = uri.origin + uri.path;
    html.window.history.replaceState(null, '', cleanUrl);
  }
}

void openUrl(String url) {
  html.window.location.href = url;
}
