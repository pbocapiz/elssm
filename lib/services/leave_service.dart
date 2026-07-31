import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/leave_balance.dart';

class LeaveService {
  LeaveService._();

  /// Fetches the signed-in user's leave balances (one row per leave type)
  /// from `public.v_leave_balances`, which is always the current calendar
  /// year. Pass [year] to instead get the breakdown for a specific year via
  /// `current_employee_leave_balances_for_year`, for the Leave Balance
  /// screen's Year filter.
  static Future<List<LeaveBalance>> fetchCurrentEmployeeBalances({
    int? year,
  }) async {
    if (Supabase.instance.client.auth.currentUser == null) return const [];

    final employeeId = await Supabase.instance.client.rpc(
      'current_employee_id',
    );
    if (employeeId == null) return const [];

    if (year != null) {
      final rows = await Supabase.instance.client.rpc(
        'current_employee_leave_balances_for_year',
        params: {'p_year': year},
      );
      return (rows as List)
          .map((row) => LeaveBalance.fromMap(row as Map<String, dynamic>))
          .toList();
    }

    final rows = await Supabase.instance.client
        .from('v_leave_balances')
        .select()
        .eq('employee_id', employeeId)
        .neq('leave_type_name', 'Force Leave (Mandatory)')
        .order('leave_type_id');

    return rows.map(LeaveBalance.fromMap).toList();
  }
}
