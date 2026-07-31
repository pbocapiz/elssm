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
        .neq('leave_name', 'Force Leave (Mandatory)')
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
    required DateTime effectiveDate,
  }) async {
    await Supabase.instance.client.from('els_leave_opening_balance').upsert({
      'employee_id': employeeId,
      'leave_type_id': leaveTypeId,
      'balance_year': year,
      'opening_balance': amount,
      'effective_date': _dateOnly(effectiveDate),
    }, onConflict: 'employee_id,leave_type_id,balance_year');
  }

  /// Edits an existing opening-balance row directly, from the Leave Records
  /// card -- distinct from [setOpeningBalance], which upserts by
  /// employee/type/year from the Starting Credits page.
  static Future<void> updateOpeningBalanceById({
    required int id,
    required double amount,
  }) async {
    await Supabase.instance.client
        .from('els_leave_opening_balance')
        .update({'opening_balance': amount})
        .eq('id', id);
  }

  static Future<void> deleteOpeningBalance(int id) async {
    await Supabase.instance.client
        .from('els_leave_opening_balance')
        .delete()
        .eq('id', id);
  }

  static String _dateOnly(DateTime date) =>
      date.toIso8601String().split('T').first;
}
