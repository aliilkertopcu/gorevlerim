import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/group.dart';

class GroupService {
  final SupabaseClient _client;

  GroupService(this._client);

  /// Fetch all groups the user is a member of
  Future<List<Group>> fetchUserGroups(String userId) async {
    final memberships = await _client
        .from('group_members')
        .select('group_id')
        .eq('user_id', userId);

    if (memberships.isEmpty) return [];

    final groupIds = memberships.map((m) => m['group_id'] as String).toList();

    final groupsData = await _client
        .from('groups')
        .select()
        .inFilter('id', groupIds)
        .order('created_at', ascending: true);

    return groupsData.map((g) => Group.fromJson(g)).toList();
  }

  /// Create a new group
  Future<Group> createGroup({
    required String name,
    required String createdBy,
    String color = '#667eea',
  }) async {
    final groupData = await _client.from('groups').insert({
      'name': name,
      'created_by': createdBy,
      'color': color,
    }).select().single();

    // Add creator as member
    await _client.from('group_members').insert({
      'group_id': groupData['id'],
      'user_id': createdBy,
    });

    return Group.fromJson(groupData);
  }

  /// Join a group by invite code
  Future<Group> joinGroup({
    required String inviteCode,
    required String userId,
  }) async {
    final groupData = await _client
        .from('groups')
        .select()
        .eq('invite_code', inviteCode.trim().toLowerCase())
        .maybeSingle();

    if (groupData == null) {
      throw Exception('Geçersiz davet kodu');
    }

    final group = Group.fromJson(groupData);

    // Check if already a member
    final existing = await _client
        .from('group_members')
        .select()
        .eq('group_id', group.id)
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) {
      throw Exception('Zaten bu grubun üyesisiniz');
    }

    await _client.from('group_members').insert({
      'group_id': group.id,
      'user_id': userId,
    });

    return group;
  }

  /// Get group members
  Future<List<Map<String, dynamic>>> getGroupMembers(String groupId) async {
    final members = await _client
        .from('group_members')
        .select('user_id, profiles(display_name, email)')
        .eq('group_id', groupId);

    return List<Map<String, dynamic>>.from(members);
  }

  /// Leave a group
  Future<void> leaveGroup({
    required String groupId,
    required String userId,
  }) async {
    await _client
        .from('group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('user_id', userId);
  }

  /// Delete a group (only creator)
  Future<void> deleteGroup(String groupId) async {
    await _client.from('groups').delete().eq('id', groupId);
  }
}
