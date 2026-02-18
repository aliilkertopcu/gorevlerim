import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../services/api_key_service.dart';
import '../theme/app_theme.dart';
// ignore: avoid_web_libraries_in_flutter
import 'package:web/web.dart' as web;

class GptConnectScreen extends ConsumerStatefulWidget {
  final String redirectUri;
  final String oauthState;

  const GptConnectScreen({
    super.key,
    required this.redirectUri,
    required this.oauthState,
  });

  @override
  ConsumerState<GptConnectScreen> createState() => _GptConnectScreenState();
}

class _GptConnectScreenState extends ConsumerState<GptConnectScreen> {
  bool _isLoading = false;
  String? _error;

  // Login form state
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoginLoading = false;
  String? _loginError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _redirect(String url) {
    web.window.location.href = url;
  }

  Future<void> _authorize() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final supabase = ref.read(supabaseProvider);
      final apiKeyService = ApiKeyService(supabase);
      final apiKey = await apiKeyService.getOrCreateApiKey(user.id);

      // Build redirect URL with code + state
      final uri = Uri.parse(widget.redirectUri);
      final params = Map<String, String>.from(uri.queryParameters);
      params['code'] = apiKey;
      if (widget.oauthState.isNotEmpty) params['state'] = widget.oauthState;
      final redirectWithCode = uri.replace(queryParameters: params);

      _redirect(redirectWithCode.toString());
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Bir hata oluştu: $e';
      });
    }
  }

  void _deny() {
    if (widget.redirectUri.isEmpty) return;
    final uri = Uri.parse(widget.redirectUri);
    final params = Map<String, String>.from(uri.queryParameters);
    params['error'] = 'access_denied';
    if (widget.oauthState.isNotEmpty) params['state'] = widget.oauthState;
    final redirectWithError = uri.replace(queryParameters: params);
    _redirect(redirectWithError.toString());
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _loginError = null);
    try {
      await ref.read(authServiceProvider).signInWithGoogle();
    } catch (e) {
      setState(() => _loginError = e.toString());
    }
  }

  Future<void> _signInWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      setState(() => _loginError = 'E-posta ve şifre gerekli');
      return;
    }
    setState(() {
      _isLoginLoading = true;
      _loginError = null;
    });
    try {
      await ref.read(authServiceProvider).signInWithEmail(email, password);
    } catch (e) {
      setState(() => _loginError = e.toString());
    } finally {
      if (mounted) setState(() => _isLoginLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppTheme.darkBackground : AppTheme.background;
    final cardColor = isDark ? AppTheme.darkCardBackground : Colors.white;
    final borderColor = isDark ? Colors.grey[700]! : const Color(0xFFdddddd);
    final textColor = isDark ? Colors.white : const Color(0xFF1a1a2e);
    final subtextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: user == null
                ? _buildLoginView(cardColor, borderColor, textColor, subtextColor)
                : _buildConsentView(user.email ?? '', cardColor, borderColor, textColor, subtextColor),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginView(Color cardColor, Color borderColor, Color textColor, Color subtextColor) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.check_circle_rounded, size: 56, color: AppTheme.primaryColor),
        const SizedBox(height: 16),
        Text(
          'Görevlerim',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textColor),
        ),
        const SizedBox(height: 8),
        Text(
          'ChatGPT bağlantısı için giriş yapın',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: subtextColor),
        ),
        const SizedBox(height: 32),

        // Google Sign-In
        OutlinedButton.icon(
          onPressed: _signInWithGoogle,
          icon: const Icon(Icons.login, size: 18),
          label: const Text('Google ile giriş yap'),
          style: OutlinedButton.styleFrom(
            foregroundColor: textColor,
            side: BorderSide(color: borderColor),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),

        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: Divider(color: borderColor)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('veya', style: TextStyle(color: subtextColor, fontSize: 13)),
          ),
          Expanded(child: Divider(color: borderColor)),
        ]),
        const SizedBox(height: 16),

        // Email field
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            labelText: 'E-posta',
            labelStyle: TextStyle(color: subtextColor),
            filled: true,
            fillColor: cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Password field
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            labelText: 'Şifre',
            labelStyle: TextStyle(color: subtextColor),
            filled: true,
            fillColor: cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: subtextColor,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          onSubmitted: (_) => _signInWithEmail(),
        ),

        if (_loginError != null) ...[
          const SizedBox(height: 12),
          Text(_loginError!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
        ],

        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _isLoginLoading ? null : _signInWithEmail,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isLoginLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Giriş Yap', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildConsentView(String email, Color cardColor, Color borderColor, Color textColor, Color subtextColor) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // App icon + ChatGPT icon
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.check_circle_rounded, size: 36, color: AppTheme.primaryColor),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.swap_horiz_rounded, color: subtextColor, size: 28),
            ),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.smart_toy_rounded, size: 36, color: Colors.green),
            ),
          ],
        ),
        const SizedBox(height: 24),

        Text(
          'ChatGPT Bağlantısı',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
        ),
        const SizedBox(height: 8),
        Text(
          email,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: subtextColor),
        ),
        const SizedBox(height: 24),

        // Permission card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ChatGPT aşağıdaki izinleri talep ediyor:',
                style: TextStyle(fontSize: 13, color: subtextColor),
              ),
              const SizedBox(height: 12),
              _permissionRow(Icons.list_alt_rounded, 'Görevlerinizi görüntüleme', textColor),
              const SizedBox(height: 8),
              _permissionRow(Icons.add_task_rounded, 'Görev ekleme ve güncelleme', textColor),
              const SizedBox(height: 8),
              _permissionRow(Icons.check_rounded, 'Görevleri tamamlama', textColor),
            ],
          ),
        ),

        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13), textAlign: TextAlign.center),
        ],

        const SizedBox(height: 24),

        // Authorize button
        ElevatedButton(
          onPressed: _isLoading ? null : _authorize,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isLoading
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('İzin Ver', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 12),

        // Deny button
        TextButton(
          onPressed: _isLoading ? null : _deny,
          style: TextButton.styleFrom(
            foregroundColor: subtextColor,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: const Text('Reddet', style: TextStyle(fontSize: 15)),
        ),

        const SizedBox(height: 16),
        Text(
          'Bu işlem ChatGPT\'nin görevlerinize erişmesine izin verir. '
          'İstediğiniz zaman uygulamadan API anahtarınızı yenileyerek erişimi iptal edebilirsiniz.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: subtextColor),
        ),
      ],
    );
  }

  Widget _permissionRow(IconData icon, String text, Color textColor) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryColor),
        const SizedBox(width: 10),
        Text(text, style: TextStyle(fontSize: 14, color: textColor)),
      ],
    );
  }
}
