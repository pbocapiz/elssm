class OfficeEmployeeLeaveBalance {
  const OfficeEmployeeLeaveBalance({
    required this.employeeId,
    required this.fullName,
    required this.employeeNo,
    required this.availableBalance,
  });

  factory OfficeEmployeeLeaveBalance.fromMap(Map<String, dynamic> map) {
    return OfficeEmployeeLeaveBalance(
      employeeId: map['employee_id'] as int,
      fullName: (map['full_name'] as String?) ?? '',
      employeeNo: map['employee_no'] as String?,
      availableBalance: map['available_balance'] == null
          ? 0
          : double.parse(map['available_balance'].toString()),
    );
  }

  final int employeeId;
  final String fullName;
  final String? employeeNo;
  final double availableBalance;
}
