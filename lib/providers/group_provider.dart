import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/group.dart';
import '../services/group_service.dart';
import '../theme/app_theme.dart';
import 'auth_provider.dart';
import 'task_provider.dart';

final groupServiceProvider = Provider<GroupService>((ref) {
  return GroupService(ref.watch(supabaseProvider));
});

final userGroupsProvider = FutureProvider.autoDispose<List<Group>>((ref) async {
  final groupService = ref.watch(groupServiceProvider);
  final user = ref.watch(currentUserProvider);

  if (user == null) return [];

  return groupService.fetchUserGroups(user.id);
});

/// Provides the currently selected group (null if user's personal tasks)
final currentGroupProvider = Provider<Group?>((ref) {
  final owner = ref.watch(ownerContextProvider);
  final groupsAsync = ref.watch(userGroupsProvider);

  if (owner == null || owner.ownerType == 'user') return null;

  return groupsAsync.when(
    data: (groups) => groups.where((g) => g.id == owner.ownerId).firstOrNull,
    loading: () => null,
    error: (_, _) => null,
  );
});

/// Provides the color for the currently selected owner (user or group)
final currentOwnerColorProvider = Provider<Color>((ref) {
  final owner = ref.watch(ownerContextProvider);
  final groupsAsync = ref.watch(userGroupsProvider);

  if (owner == null || owner.ownerType == 'user') {
    return AppTheme.primaryColor;
  }

  return groupsAsync.when(
    data: (groups) {
      final group = groups.where((g) => g.id == owner.ownerId).firstOrNull;
      if (group == null) return AppTheme.primaryColor;
      final hex = group.color.replaceFirst('#', '');
      final fullHex = hex.length == 6 ? 'FF$hex' : hex;
      return Color(int.parse(fullHex, radix: 16));
    },
    loading: () => AppTheme.primaryColor,
    error: (_, _) => AppTheme.primaryColor,
  );
});

/// Provides invites for a group
final groupInvitesProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, groupId) async {
  final groupService = ref.watch(groupServiceProvider);
  return groupService.getGroupInvites(groupId);
});

/// Provides invite data by token (for invite preview page)
final inviteByTokenProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, token) async {
  final groupService = ref.watch(groupServiceProvider);
  return groupService.getInviteByToken(token);
});
