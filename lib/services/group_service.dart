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

  /// Get group members with profile info
  Future<List<Map<String, dynamic>>> getGroupMembers(String groupId) async {
    final members = await _client
        .from('group_members')
        .select('user_id, joined_at, profiles(display_name, email)')
        .eq('group_id', groupId);

    return List<Map<String, dynamic>>.from(members);
  }

  /// Remove a member from a group (creator only, enforced by RLS)
  Future<void> removeMember({
    required String groupId,
    required String userId,
  }) async {
    await _client
        .from('group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('user_id', userId);
  }

  /// Update group name (creator only, enforced by RLS)
  Future<void> updateGroupName({
    required String groupId,
    required String name,
  }) async {
    await _client
        .from('groups')
        .update({'name': name})
        .eq('id', groupId);
  }

  /// Update group description (creator only, enforced by RLS)
  Future<void> updateGroupDescription({
    required String groupId,
    required String? description,
  }) async {
    await _client
        .from('groups')
        .update({'description': description})
        .eq('id', groupId);
  }

  /// Log a group activity
  Future<void> logActivity({
    required String groupId,
    required String userId,
    required String action,
    String? details,
  }) async {
    await _client.from('group_activity_log').insert({
      'group_id': groupId,
      'user_id': userId,
      'action': action,
      'details': details,
    });
  }

  /// Fetch group activity log
  Future<List<Map<String, dynamic>>> getActivityLog(String groupId) async {
    final logs = await _client
        .from('group_activity_log')
        .select('id, user_id, action, details, created_at, profiles(display_name)')
        .eq('group_id', groupId)
        .order('created_at', ascending: false)
        .limit(50);

    return List<Map<String, dynamic>>.from(logs);
  }

  /// Update group color (creator only, enforced by RLS)
  Future<void> updateGroupColor({
    required String groupId,
    required String color,
  }) async {
    await _client
        .from('groups')
        .update({'color': color})
        .eq('id', groupId);
  }

  /// Update group settings (creator only, enforced by RLS)
  Future<void> updateGroupSettings({
    required String groupId,
    required Map<String, dynamic> settings,
  }) async {
    await _client
        .from('groups')
        .update({'settings': settings})
        .eq('id', groupId);
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
