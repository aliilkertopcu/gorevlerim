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

    // Log BEFORE joining (user will have access after insert)
    await _client.from('group_members').insert({
      'group_id': group.id,
      'user_id': userId,
    });

    // Log after joining (now user is a member and can insert logs)
    await logActivity(
      groupId: group.id,
      userId: userId,
      action: 'member_joined',
      details: 'Gruba katıldı',
    );

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
    required String removedByUserId,
  }) async {
    // Log before removing (member still has RLS access)
    await logActivity(
      groupId: groupId,
      userId: removedByUserId,
      action: 'member_removed',
      details: 'Üye gruptan çıkarıldı',
    );

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

  /// Fetch group activity log with pagination
  Future<List<Map<String, dynamic>>> getActivityLog(
    String groupId, {
    int limit = 20,
    int offset = 0,
  }) async {
    final logs = await _client
        .from('group_activity_log')
        .select('id, user_id, action, details, created_at, profiles(display_name)')
        .eq('group_id', groupId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

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

  /// Leave a group (log before removing membership)
  Future<void> leaveGroup({
    required String groupId,
    required String userId,
  }) async {
    // Log BEFORE leaving (user still has RLS access)
    await logActivity(
      groupId: groupId,
      userId: userId,
      action: 'member_left',
      details: 'Gruptan ayrıldı',
    );

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

  // === Invite Link Methods ===

  /// Create an invite link for a group
  Future<Map<String, dynamic>> createInvite({
    required String groupId,
    required String createdBy,
    Duration? expiresIn,
  }) async {
    final data = <String, dynamic>{
      'group_id': groupId,
      'created_by': createdBy,
    };

    if (expiresIn != null) {
      data['expires_at'] = DateTime.now().add(expiresIn).toIso8601String();
    }

    final result = await _client
        .from('group_invites')
        .insert(data)
        .select()
        .single();

    await logActivity(
      groupId: groupId,
      userId: createdBy,
      action: 'invite_created',
      details: 'Davet bağlantısı oluşturuldu',
    );

    return result;
  }

  /// Delete an invite
  Future<void> deleteInvite(String inviteId, {required String groupId, required String userId}) async {
    await _client.from('group_invites').delete().eq('id', inviteId);

    await logActivity(
      groupId: groupId,
      userId: userId,
      action: 'invite_deleted',
      details: 'Davet bağlantısı silindi',
    );
  }

  /// Get all invites for a group
  Future<List<Map<String, dynamic>>> getGroupInvites(String groupId) async {
    final invites = await _client
        .from('group_invites')
        .select()
        .eq('group_id', groupId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(invites);
  }

  /// Get invite by token (for preview page)
  Future<Map<String, dynamic>?> getInviteByToken(String token) async {
    final invite = await _client
        .from('group_invites')
        .select('*, groups(id, name, description, created_by, color, profiles:created_by(display_name))')
        .eq('token', token)
        .maybeSingle();

    return invite;
  }

  /// Join a group via invite token
  Future<Group> joinGroupByInvite({
    required String token,
    required String userId,
  }) async {
    // Get invite
    final invite = await _client
        .from('group_invites')
        .select('*, groups(*)')
        .eq('token', token)
        .maybeSingle();

    if (invite == null) {
      throw Exception('Geçersiz davet bağlantısı');
    }

    // Check expiry
    if (invite['expires_at'] != null) {
      final expiresAt = DateTime.parse(invite['expires_at'] as String);
      if (expiresAt.isBefore(DateTime.now())) {
        throw Exception('Bu davet bağlantısının süresi dolmuş');
      }
    }

    final groupId = invite['group_id'] as String;
    final group = Group.fromJson(invite['groups'] as Map<String, dynamic>);

    // Check if already a member
    final existing = await _client
        .from('group_members')
        .select()
        .eq('group_id', groupId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) {
      throw Exception('Zaten bu grubun üyesisiniz');
    }

    await _client.from('group_members').insert({
      'group_id': groupId,
      'user_id': userId,
    });

    await logActivity(
      groupId: groupId,
      userId: userId,
      action: 'member_joined',
      details: 'Davet bağlantısıyla katıldı',
    );

    return group;
  }
}
