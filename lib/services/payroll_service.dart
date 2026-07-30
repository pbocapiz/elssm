import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/office_employee.dart';
import '../models/payroll_entry.dart';

class PayrollService {
  PayrollService._();

  /// Employees the caller can enter payroll for (their own office if an
  /// Approver, every office if an Admin -- enforced by RLS, not by this
  /// query).
  static Future<List<OfficeEmployee>> fetchOfficeEmployees() async {
    final rows = await Supabase.instance.client.rpc('office_employees');
    return (rows as List)
        .map((row) => OfficeEmployee.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// The signed-in user's own payroll rows for the given year.
  static Future<List<PayrollEntry>> fetchOwnPayroll(int year) async {
    final employeeId = await Supabase.instance.client.rpc(
      'current_employee_id',
    );
    if (employeeId == null) return const [];
    return _fetchPayroll(employeeId: employeeId as int, year: year);
  }

  /// A specific employee's payroll rows for the given year (Approver/Admin
  /// use -- RLS scopes which employeeId values are actually readable).
  static Future<List<PayrollEntry>> fetchEmployeePayroll({
    required int employeeId,
    required int year,
  }) {
    return _fetchPayroll(employeeId: employeeId, year: year);
  }

  static Future<List<PayrollEntry>> _fetchPayroll({
    required int employeeId,
    required int year,
  }) async {
    final rows = await Supabase.instance.client
        .from('els_payroll')
        .select()
        .eq('employee_id', employeeId)
        .eq('year', year)
        .order('month');
    return PayrollEntry.fillYear(
      rows.map((row) => PayrollEntry.fromMap(row)).toList(),
    );
  }

  static Future<void> setPayrollEntry({
    required int employeeId,
    required int year,
    required int month,
    required double firstQuincena,
    required double secondQuincena,
  }) async {
    await Supabase.instance.client.from('els_payroll').upsert({
      'employee_id': employeeId,
      'year': year,
      'month': month,
      'first_quincena': firstQuincena,
      'second_quincena': secondQuincena,
    }, onConflict: 'employee_id,year,month');
  }

  /// Sets an employee's default 1st/2nd Quincena amounts, used to pre-fill
  /// any month with no els_payroll row yet. Security-definer RPC since
  /// Approvers have no general update policy on els_employees -- see
  /// 020_split_payroll_defaults.sql.
  static Future<void> setEmployeeDefaults({
    required int employeeId,
    required double firstQuincena,
    required double secondQuincena,
  }) async {
    await Supabase.instance.client.rpc(
      'set_employee_payroll_defaults',
      params: {
        'p_employee_id': employeeId,
        'p_first_quincena': firstQuincena,
        'p_second_quincena': secondQuincena,
      },
    );
  }
}
