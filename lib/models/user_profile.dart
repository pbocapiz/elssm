/// The signed-in user's full profile: `public.users` (+ resolved office
/// name) combined with their linked `public.els_employees` record, as
/// returned by `public.v_user_profiles`. `employeeId` and the fields below
/// it are null until an Admin/Approver links the user to an employee
/// record (see EmployeeService.addEmployee).
class UserProfile {
  const UserProfile({
    required this.firstName,
    required this.middleName,
    required this.lastName,
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

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    final dateHired = map['date_hired'] as String?;
    return UserProfile(
      firstName: (map['firstname'] as String?) ?? '',
      middleName: map['middlename'] as String?,
      lastName: (map['lastname'] as String?) ?? '',
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

  final String firstName;
  final String? middleName;
  final String lastName;
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
    ].where((part) => part != null && part.trim().isNotEmpty);
    return parts.isEmpty ? 'Unnamed User' : parts.join(' ');
  }

  String get accessLevelLabel => switch (accessLevel) {
    1 => 'Admin',
    2 => 'Approver',
    _ => 'Employee',
  };

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}
