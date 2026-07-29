import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/leave_type.dart';
import '../models/office_employee_balance.dart';

class OpeningBalanceService {
  OpeningBalanceService._();

  static Future<List<LeaveType>> fetchLeaveTypes() async {
    final rows = await Supabase.instance.client
        .from('els_leave_types')
        .select('id, leave_name')
        .eq('is_active', true)
        .order('leave_name');
    return rows.map(LeaveType.fromMap).toList();
  }

  /// Employees this user can manage (their own office if an Approver, every
  /// office if an Admin — enforced by RLS, not by this query), with their
  /// current opening balance for the given leave type + year.
  static Future<List<OfficeEmployeeBalance>> fetchOpeningBalances({
    required int leaveTypeId,
    required int year,
  }) async {
    final rows = await Supabase.instance.client.rpc(
      'office_employee_opening_balances',
      params: {'p_leave_type_id': leaveTypeId, 'p_year': year},
    );
    return (rows as List)
        .map(
          (row) => OfficeEmployeeBalance.fromMap(row as Map<String, dynamic>),
        )
        .toList();
  }

  static Future<void> setOpeningBalance({
    required int employeeId,
    required int leaveTypeId,
    required int year,
    required double amount,
  }) async {
    await Supabase.instance.client.from('els_leave_opening_balance').upsert({
      'employee_id': employeeId,
      'leave_type_id': leaveTypeId,
      'balance_year': year,
      'opening_balance': amount,
    }, onConflict: 'employee_id,leave_type_id,balance_year');
  }
}
