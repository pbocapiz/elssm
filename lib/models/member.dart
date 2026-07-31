/// A row from `public.v_user_profiles` for the "Members" admin/approver
/// screen -- every user visible to the caller (all users for an Admin,
/// same-office users for an Approver -- enforced by RLS on the underlying
/// `public.users` table, not by this model). `employeeId` and the fields
/// below it are null until this user is linked to an `els_employees`
/// record (see EmployeeService.addEmployee).
class Member {
  const Member({
    required this.id,
    required this.firstName,
    required this.middleName,
    required this.lastName,
    this.suffix,
    required this.email,
    required this.position,
    required this.officeName,
    required this.accessLevel,
    required this.isActive,
    this.employeeId,
    this.employeeNo,
    this.employmentStatus,
    this.civilStatus,
    this.gsisNo,
    this.tinNo,
    this.dateHired,
    this.divisionSection,
    this.immediateSupervisor,
    this.philhealthNo,
    this.pagibigNo,
  });

  factory Member.fromMap(Map<String, dynamic> map) {
    final dateHired = map['date_hired'] as String?;
    return Member(
      id: map['id'] as String,
      firstName: (map['firstname'] as String?) ?? '',
      middleName: map['middlename'] as String?,
      lastName: (map['lastname'] as String?) ?? '',
      suffix: map['suffix'] as String?,
      email: (map['email'] as String?) ?? '',
      position: (map['position'] as String?) ?? 'Employee',
      officeName: (map['officename'] as String?) ?? 'Unassigned Office',
      accessLevel: (map['accesslevel'] as int?) ?? 3,
      isActive: (map['is_active'] as bool?) ?? true,
      employeeId: map['employee_id'] as int?,
      employeeNo: map['employee_no'] as String?,
      employmentStatus: map['employement_status'] as String?,
      civilStatus: map['civil_status'] as String?,
      gsisNo: map['gsis_no'] as String?,
      tinNo: map['tin_no'] as String?,
      dateHired: dateHired == null ? null : DateTime.tryParse(dateHired),
      divisionSection: map['division_section'] as String?,
      immediateSupervisor: map['immediate_supervisor'] as String?,
      philhealthNo: map['philhealth_no'] as String?,
      pagibigNo: map['pagibig_no'] as String?,
    );
  }

  final String id;
  final String firstName;
  final String? middleName;
  final String lastName;
  final String? suffix;
  final String email;
  final String position;
  final String officeName;

  /// 1 = Admin, 2 = Approver/Supervisor, 3 = Employee.
  final int accessLevel;
  final bool isActive;

  /// Null until this user is linked to an `els_employees` record.
  final int? employeeId;
  final String? employeeNo;
  final String? employmentStatus;
  final String? civilStatus;
  final String? gsisNo;
  final String? tinNo;
  final DateTime? dateHired;
  final String? divisionSection;
  final String? immediateSupervisor;
  final String? philhealthNo;
  final String? pagibigNo;

  bool get isLinkedToEmployeeRecord => employeeId != null;

  String get fullName {
    final parts = [
      firstName,
      middleName,
      lastName,
      suffix,
    ].where((part) => part != null && part.trim().isNotEmpty);
    return parts.isEmpty ? 'Unnamed User' : parts.join(' ');
  }

  String get accessLevelLabel => switch (accessLevel) {
    1 => 'Admin',
    2 => 'Approver',
    _ => 'Employee',
  };
}
