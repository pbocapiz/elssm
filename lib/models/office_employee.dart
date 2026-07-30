class OfficeEmployee {
  const OfficeEmployee({
    required this.employeeId,
    required this.fullName,
    required this.employeeNo,
    required this.defaultFirstQuincena,
    required this.defaultSecondQuincena,
  });

  factory OfficeEmployee.fromMap(Map<String, dynamic> map) {
    double? asDouble(Object? value) =>
        value == null ? null : double.parse(value.toString());

    return OfficeEmployee(
      employeeId: map['employee_id'] as int,
      fullName: (map['full_name'] as String?) ?? '',
      employeeNo: map['employee_no'] as String?,
      defaultFirstQuincena: asDouble(map['default_first_quincena']),
      defaultSecondQuincena: asDouble(map['default_second_quincena']),
    );
  }

  final int employeeId;
  final String fullName;
  final String? employeeNo;

  /// Null until an Admin/Approver sets it (see
  /// PayrollService.setEmployeeDefaults). Government contribution
  /// deductions (GSIS, PhilHealth, Pag-IBIG, tax) typically fall on one
  /// quincena and not the other, so these are independent, not a single
  /// salary halved.
  final double? defaultFirstQuincena;
  final double? defaultSecondQuincena;

  /// Value equality on employeeId alone: after saving new defaults,
  /// PayrollPage rebuilds a fresh OfficeEmployee to reflect them, and that
  /// new instance must still match its entry in the fetched employee list
  /// for DropdownButtonFormField's initialValue -- otherwise it throws
  /// ("zero or 2 or more DropdownMenuItems... with the same value").
  @override
  bool operator ==(Object other) =>
      other is OfficeEmployee && other.employeeId == employeeId;

  @override
  int get hashCode => employeeId.hashCode;
}
