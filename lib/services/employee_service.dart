import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/unlinked_user.dart';

class EmployeeService {
  EmployeeService._();

  /// accesslevel-3 users with no els_employees row yet, scoped by RLS to
  /// the caller's own office (or every office, for an Admin).
  static Future<List<UnlinkedUser>> fetchUnlinkedUsers() async {
    final rows = await Supabase.instance.client.rpc('unlinked_employee_users');
    return (rows as List)
        .map((row) => UnlinkedUser.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  static Future<void> addEmployee({
    required int usersId,
    String? employeeNo,
  }) async {
    await Supabase.instance.client.from('els_employees').insert({
      'users_id': usersId,
      if (employeeNo != null && employeeNo.trim().isNotEmpty)
        'employee_no': employeeNo.trim(),
    });
  }
}
