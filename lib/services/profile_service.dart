import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/employee.dart';
import '../models/user_profile.dart';

class ProfileService {
  ProfileService._();

  /// Fetches the signed-in user's row from `public.v_user_profiles`
  /// (users joined with gl_offices and, since 006, els_employees) and maps
  /// it into an [Employee] for display in the sidebar.
  static Future<Employee?> fetchCurrentEmployee() async {
    final row = await _fetchCurrentProfileRow();
    if (row == null) return null;

    final nameParts = [
      row['firstname'] as String?,
      row['middlename'] as String?,
      row['lastname'] as String?,
    ].where((part) => part != null && part.trim().isNotEmpty);

    return Employee(
      name: nameParts.isEmpty ? 'Unnamed User' : nameParts.join(' '),
      officeName: (row['officename'] as String?) ?? 'Unassigned Office',
      position: (row['position'] as String?) ?? 'Employee',
      accessLevel: (row['accesslevel'] as int?) ?? 3,
    );
  }

  /// Fetches the signed-in user's full profile -- `public.users` combined
  /// with their linked `public.els_employees` record -- for the Profile
  /// screen.
  static Future<UserProfile?> fetchCurrentProfile() async {
    final row = await _fetchCurrentProfileRow();
    return row == null ? null : UserProfile.fromMap(row);
  }

  /// Updates the signed-in user's own `public.els_employees` row. Requires
  /// [employeeId] (i.e. the user must already be linked to an employee
  /// record -- see EmployeeService.addEmployee) and is allowed by the
  /// "Employees can update own record" RLS policy (007).
  static Future<void> updateEmployment({
    required int employeeId,
    String? employeeNo,
    String? employmentStatus,
    String? civilStatus,
    String? gsisNo,
    String? tinNo,
    DateTime? dateHired,
    String? divisionSection,
    String? immediateSupervisor,
    String? philhealthNo,
    String? pagibigNo,
  }) async {
    await Supabase.instance.client
        .from('els_employees')
        .update({
          'employee_no': employeeNo,
          'employement_status': employmentStatus,
          'civil_status': civilStatus,
          'gsis_no': gsisNo,
          'tin_no': tinNo,
          'date_hired': dateHired == null
              ? null
              : '${dateHired.year.toString().padLeft(4, '0')}-'
                    '${dateHired.month.toString().padLeft(2, '0')}-'
                    '${dateHired.day.toString().padLeft(2, '0')}',
          'division_section': divisionSection,
          'immediate_supervisor': immediateSupervisor,
          'philhealth_no': philhealthNo,
          'pagibig_no': pagibigNo,
        })
        .eq('id', employeeId);
  }

  static Future<Map<String, dynamic>?> _fetchCurrentProfileRow() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return null;

    return Supabase.instance.client
        .from('v_user_profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
  }
}
