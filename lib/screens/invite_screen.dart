import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/group_provider.dart';
import '../providers/task_provider.dart';

class InviteScreen extends ConsumerWidget {
  final String token;

  const InviteScreen({super.key, required this.token});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inviteAsync = ref.watch(inviteByTokenProvider(token));
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: inviteAsync.when(
                data: (invite) {
                  if (invite == null) {
                    return _buildError('Geçersiz davet bağlantısı');
                  }

                  // Check expiry
                  if (invite['expires_at'] != null) {
                    final expiresAt = DateTime.tryParse(invite['expires_at'] as String);
                    if (expiresAt != null && expiresAt.isBefore(DateTime.now())) {
                      return _buildError('Bu davet bağlantısının süresi dolmuş');
                    }
                  }

                  final group = invite['groups'] as Map<String, dynamic>?;
                  if (group == null) {
                    return _buildError('Grup bulunamadı');
                  }

                  final groupName = group['name'] as String? ?? 'Bilinmeyen Grup';
                  final description = group['description'] as String?;
                  final colorHex = group['color'] as String? ?? '#667eea';
                  final creatorProfile = group['profiles'] as Map<String, dynamic>?;
                  final creatorName = creatorProfile?['display_name'] as String? ?? 'Bilinmeyen';
                  final groupColor = _parseColor(colorHex);

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Group avatar
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: groupColor,
                        child: Text(
                          groupName[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        groupName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Kurucu: $creatorName',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                      if (description != null && description.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).hintColor.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            description,
                            style: const TextStyle(fontSize: 14, height: 1.4),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                      if (user == null) ...[
                        // Not logged in
                        const Text(
                          'Gruba katılmak için giriş yapmanız gerekiyor',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => context.go('/login'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: groupColor,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Giriş Yap', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                      ] else ...[
                        // Logged in — show join button
                        _JoinButton(
                          token: token,
                          groupColor: groupColor,
                        ),
                      ],
                    ],
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => _buildError('Hata: $e'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, size: 64, color: Colors.red),
        const SizedBox(height: 16),
        Text(
          message,
          style: const TextStyle(fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Color _parseColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}

class _JoinButton extends ConsumerStatefulWidget {
  final String token;
  final Color groupColor;

  const _JoinButton({required this.token, required this.groupColor});

  @override
  ConsumerState<_JoinButton> createState() => _JoinButtonState();
}

class _JoinButtonState extends ConsumerState<_JoinButton> {
  bool _isLoading = false;
  String? _error;
  bool _joined = false;

  @override
  Widget build(BuildContext context) {
    if (_joined) {
      return Column(
        children: [
          const Icon(Icons.check_circle, size: 48, color: Colors.green),
          const SizedBox(height: 12),
          const Text(
            'Gruba katıldınız!',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.go('/'),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.groupColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Ana Sayfaya Git', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        if (_error != null) ...[
          Text(
            _error!,
            style: const TextStyle(color: Colors.red, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _joinGroup,
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.groupColor,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Katıl', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Future<void> _joinGroup() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final group = await ref.read(groupServiceProvider).joinGroupByInvite(
        token: widget.token,
        userId: user.id,
      );
      ref.invalidate(userGroupsProvider);
      // Switch view to the joined group
      final owner = OwnerContext(ownerId: group.id, ownerType: 'group');
      ref.read(ownerContextProvider.notifier).state = owner;
      ViewStatePersistence.saveOwnerContext(owner);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _joined = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }
}
