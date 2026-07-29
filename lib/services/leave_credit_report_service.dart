import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/leave_credit_report_row.dart';

class LeaveCreditReportService {
  LeaveCreditReportService._();

  /// One row per (employee, active leave type) the caller can see for
  /// [year] -- own record only for an Employee, office-scoped for an
  /// Approver, everyone for an Admin (enforced by RLS, not by this query).
  static Future<List<LeaveCreditReportRow>> fetchReport({
    required int year,
  }) async {
    final rows = await Supabase.instance.client.rpc(
      'leave_credit_report',
      params: {'p_year': year},
    );
    return (rows as List)
        .map(
          (row) => LeaveCreditReportRow.fromMap(row as Map<String, dynamic>),
        )
        .toList();
  }
}
