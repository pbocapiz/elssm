import 'package:supabase_flutter/supabase_flutter.dart';

class LeaveApplicationService {
  LeaveApplicationService._();

  static Future<void> submitApplication({
    required int leaveTypeId,
    required DateTime startDate,
    required int days,
    required bool withPay,
    String? remarks,
  }) async {
    final employeeId = await Supabase.instance.client.rpc(
      'current_employee_id',
    );
    if (employeeId == null) {
      throw StateError('No employee record is linked to your account yet.');
    }

    await Supabase.instance.client.from('els_leave_applications').insert({
      'employee_id': employeeId,
      'leave_type_id': leaveTypeId,
      'leave_date': _dateOnly(startDate),
      'days': days,
      'with_pay': withPay,
      if (remarks != null && remarks.trim().isNotEmpty)
        'remarks': remarks.trim(),
    });
  }

  /// Approve or reject a PENDING application. RLS on els_leave_applications
  /// already restricts this to Admins (any office) and Approvers (their
  /// own office) -- no extra check needed here.
  static Future<void> updateStatus({
    required int applicationId,
    required String status,
  }) async {
    await Supabase.instance.client
        .from('els_leave_applications')
        .update({'status': status})
        .eq('id', applicationId);
  }

  static String _dateOnly(DateTime date) =>
      date.toIso8601String().split('T').first;
}
