import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/group.dart';
import '../services/group_service.dart';
import 'auth_provider.dart';

final groupServiceProvider = Provider<GroupService>((ref) {
  return GroupService(ref.watch(supabaseProvider));
});

final userGroupsProvider = FutureProvider.autoDispose<List<Group>>((ref) async {
  final groupService = ref.watch(groupServiceProvider);
  final user = ref.watch(currentUserProvider);

  if (user == null) return [];

  return groupService.fetchUserGroups(user.id);
});
