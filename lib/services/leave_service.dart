import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/leave_balance.dart';

class LeaveService {
  LeaveService._();

  /// Fetches the signed-in user's leave balances (one row per leave type,
  /// for the current year) from `public.v_leave_balances`.
  static Future<List<LeaveBalance>> fetchCurrentEmployeeBalances() async {
    if (Supabase.instance.client.auth.currentUser == null) return const [];

    final employeeId = await Supabase.instance.client.rpc(
      'current_employee_id',
    );
    if (employeeId == null) return const [];

    final rows = await Supabase.instance.client
        .from('v_leave_balances')
        .select()
        .eq('employee_id', employeeId)
        .order('leave_type_id');

    return rows.map(LeaveBalance.fromMap).toList();
  }
}
