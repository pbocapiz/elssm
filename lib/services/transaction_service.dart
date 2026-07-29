import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/leave_transaction.dart';

class TransactionService {
  TransactionService._();

  /// The signed-in employee's leave transaction history (credits,
  /// deductions, applications), newest first. Pass [leaveTypeId] to filter
  /// to a single leave type, or leave it null for all.
  static Future<List<LeaveTransaction>> fetchCurrentEmployeeTransactions({
    int? leaveTypeId,
  }) async {
    if (Supabase.instance.client.auth.currentUser == null) return const [];

    final employeeId = await Supabase.instance.client.rpc(
      'current_employee_id',
    );
    if (employeeId == null) return const [];

    var query = Supabase.instance.client
        .from('v_leave_transactions')
        .select()
        .eq('employee_id', employeeId);
    if (leaveTypeId != null) {
      query = query.eq('leave_type_id', leaveTypeId);
    }

    final rows = await query.order('transaction_date', ascending: false);
    return rows.map(LeaveTransaction.fromMap).toList();
  }

  /// Leave transactions across every employee the caller can see (their own
  /// office for an Approver, every office for an Admin) -- scoped entirely
  /// by RLS on the underlying tables, same as everywhere else. Pass
  /// [leaveTypeId] to filter to a single leave type, or leave it null for
  /// all.
  static Future<List<LeaveTransaction>> fetchOfficeTransactions({
    int? leaveTypeId,
  }) async {
    var query = Supabase.instance.client.from('v_leave_transactions').select();
    if (leaveTypeId != null) {
      query = query.eq('leave_type_id', leaveTypeId);
    }

    final rows = await query.order('transaction_date', ascending: false);
    return rows.map(LeaveTransaction.fromMap).toList();
  }
}
