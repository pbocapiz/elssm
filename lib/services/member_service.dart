import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/member.dart';

class MemberService {
  MemberService._();

  /// Every user visible to the caller -- all of them for an Admin, same
  /// office only for an Approver (enforced by RLS on public.users, not by
  /// this query). Pending (is_active = false) members sort first.
  static Future<List<Member>> fetchMembers() async {
    final rows = await Supabase.instance.client
        .from('v_user_profiles')
        .select()
        .order('is_active')
        .order('lastname');
    return (rows as List)
        .map((row) => Member.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  static Future<void> setActive({
    required String userId,
    required bool isActive,
  }) async {
    await Supabase.instance.client
        .from('users')
        .update({'is_active': isActive})
        .eq('id', userId);
  }

  /// Edits Position/Access Level/Status together, from the Members screen's
  /// edit card. RLS scopes what a caller can actually change: Admins can
  /// edit anyone, Approvers only accesslevel-3 employees in their own
  /// office and only up to accesslevel 2 (see 023_approver_admin_edit_members.sql).
  static Future<void> updateMember({
    required String userId,
    required String position,
    required int accessLevel,
    required bool isActive,
  }) async {
    await Supabase.instance.client
        .from('users')
        .update({
          'position': position,
          'accesslevel': accessLevel,
          'is_active': isActive,
        })
        .eq('id', userId);
  }
}
