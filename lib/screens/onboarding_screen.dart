import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../data/changelog.dart';
import '../version.dart';
import '../widgets/youtube_embed.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  static const String _videoId = 'v2gCtEVzm9E';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF1a1a2e),
                    const Color(0xFF16213e),
                    const Color(0xFF0f3460),
                  ]
                : [
                    const Color(0xFF667eea),
                    const Color(0xFF764ba2),
                  ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        } else {
                          GoRouter.of(context).go('/login');
                        }
                      },
                    ),
                    const Expanded(
                      child: Text(
                        'Görevlerim',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'v$appVersion',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // YouTube Video
                          if (_videoId != 'PLACEHOLDER') ...[
                            const YouTubeEmbed(videoId: _videoId),
                            const SizedBox(height: 16),
                          ],
                          // Proje Hikayesi
                          _buildCard(
                            context,
                            isDark: isDark,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.asset(
                                        'assets/images/logo.png',
                                        width: 48,
                                        height: 48,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Text(
                                        'Hikaye',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Bir sabah daha kafam açılmadan köpeği çıkartmıştım, hep gittiğimiz çimenlikte Sofi\'nin kaka yapmasını bekliyordum; tasma elimde. Kafamda parça pinçik bisürü cümle uçuşuyor, gözlerim çapaklı ve kısık 😂 "Of bugün yapacak çok şey var..", "Bunu kesin unutucam akşama kadar..", keşke daha erken kalksaydım yetişmeyecek bu gün de memnuniyetsizlik hisleriyle bir duygu girdabı olmuş dönenirken, kendime ses kaydı atayım dedim 💡 Aaa whatsapp yerine Claude üzerinden atayım, hem metne çevirir bidaha kendimin bomboş düşünen sessizliğini dinlemek zorunda kalmam dedim. O da olsun bu da olsun derken geldiğimiz nokta budur ahahahah 😆 Katıldığın ve katkıların için şimdiden çok teşekkürler!',
                                  style: TextStyle(
                                    fontSize: 15,
                                    height: 1.6,
                                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Changelog
                          ...changelog.map((entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildChangelogCard(context, entry, isDark: isDark),
                          )),
                          // Footer
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 24),
                            child: Text(
                              'made with curiosity \u{1F9E0}\n@izmir 2026',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.5),
                                fontWeight: FontWeight.w300,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, {required bool isDark, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF2d2d2d).withValues(alpha: 0.95)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildChangelogCard(BuildContext context, ChangelogEntry entry, {required bool isDark}) {
    return _buildCard(
      context,
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Version header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF667eea).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'v${entry.version}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF667eea),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                entry.date,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[400] : Colors.grey[500],
                ),
              ),
            ],
          ),
          // Features
          if (entry.features.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.auto_awesome, size: 16, color: Color(0xFF667eea)),
                const SizedBox(width: 6),
                Text(
                  'Yeni Özellikler',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[200] : Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...entry.features.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF667eea),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      f,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
          // Fixes
          if (entry.fixes.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.build_rounded, size: 16, color: Color(0xFF28a745)),
                const SizedBox(width: 6),
                Text(
                  'Düzeltmeler',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[200] : Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...entry.fixes.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF28a745),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      f,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }
}
