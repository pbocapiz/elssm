class OfficeEmployeeBalance {
  const OfficeEmployeeBalance({
    required this.employeeId,
    required this.fullName,
    required this.employeeNo,
    required this.openingBalance,
  });

  factory OfficeEmployeeBalance.fromMap(Map<String, dynamic> map) {
    return OfficeEmployeeBalance(
      employeeId: map['employee_id'] as int,
      fullName: (map['full_name'] as String?) ?? '',
      employeeNo: map['employee_no'] as String?,
      openingBalance: map['opening_balance'] == null
          ? 0
          : double.parse(map['opening_balance'].toString()),
    );
  }

  final int employeeId;
  final String fullName;
  final String? employeeNo;
  final double openingBalance;
}
