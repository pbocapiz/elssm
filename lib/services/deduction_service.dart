import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/office_employee_leave_balance.dart';

class DeductionService {
  DeductionService._();

  /// Employees this user can record a deduction for (their own office if an
  /// Approver, every office if an Admin -- enforced by RLS, not by this
  /// query), with their current available balance for the given leave type.
  static Future<List<OfficeEmployeeLeaveBalance>> fetchOfficeBalances({
    required int leaveTypeId,
  }) async {
    final rows = await Supabase.instance.client.rpc(
      'office_employee_leave_balances',
      params: {'p_leave_type_id': leaveTypeId},
    );
    return (rows as List)
        .map(
          (row) =>
              OfficeEmployeeLeaveBalance.fromMap(row as Map<String, dynamic>),
        )
        .toList();
  }

  static Future<void> createDeduction({
    required int employeeId,
    required int leaveTypeId,
    required double amount,
    required DateTime deductionDate,
    String? remarks,
  }) async {
    await Supabase.instance.client.from('els_leave_deductions').insert({
      'employee_id': employeeId,
      'leave_type_id': leaveTypeId,
      'deduction_date': _dateOnly(deductionDate),
      'amount': amount,
      if (remarks != null && remarks.trim().isNotEmpty)
        'remarks': remarks.trim(),
    });
  }

  static String _dateOnly(DateTime date) =>
      date.toIso8601String().split('T').first;
}
