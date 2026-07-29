/// A row from `public.v_user_profiles` for the "Members" admin/approver
/// screen -- every user visible to the caller (all users for an Admin,
/// same-office users for an Approver -- enforced by RLS on the underlying
/// `public.users` table, not by this model).
class Member {
  const Member({
    required this.id,
    required this.firstName,
    required this.middleName,
    required this.lastName,
    required this.email,
    required this.position,
    required this.officeName,
    required this.accessLevel,
    required this.isActive,
  });

  factory Member.fromMap(Map<String, dynamic> map) {
    return Member(
      id: map['id'] as String,
      firstName: (map['firstname'] as String?) ?? '',
      middleName: map['middlename'] as String?,
      lastName: (map['lastname'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      position: (map['position'] as String?) ?? 'Employee',
      officeName: (map['officename'] as String?) ?? 'Unassigned Office',
      accessLevel: (map['accesslevel'] as int?) ?? 3,
      isActive: (map['is_active'] as bool?) ?? true,
    );
  }

  final String id;
  final String firstName;
  final String? middleName;
  final String lastName;
  final String email;
  final String position;
  final String officeName;

  /// 1 = Admin, 2 = Approver/Supervisor, 3 = Employee.
  final int accessLevel;
  final bool isActive;

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
}
