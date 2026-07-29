class LeaveCreditReportRow {
  const LeaveCreditReportRow({
    required this.employeeId,
    required this.employeeNo,
    required this.fullName,
    required this.leaveTypeId,
    required this.leaveTypeName,
    required this.openingBalance,
    required this.totalEarned,
    required this.totalDeducted,
    required this.totalApplied,
    required this.availableBalance,
  });

  factory LeaveCreditReportRow.fromMap(Map<String, dynamic> map) {
    double asDouble(Object? value) =>
        value == null ? 0 : double.parse(value.toString());

    return LeaveCreditReportRow(
      employeeId: map['employee_id'] as int,
      employeeNo: map['employee_no'] as String?,
      fullName: (map['full_name'] as String?) ?? '',
      leaveTypeId: map['leave_type_id'] as int,
      leaveTypeName: (map['leave_type_name'] as String?) ?? '',
      openingBalance: asDouble(map['opening_balance']),
      totalEarned: asDouble(map['total_earned']),
      totalDeducted: asDouble(map['total_deducted']),
      totalApplied: asDouble(map['total_applied']),
      availableBalance: asDouble(map['available_balance']),
    );
  }

  final int employeeId;
  final String? employeeNo;
  final String fullName;
  final int leaveTypeId;
  final String leaveTypeName;
  final double openingBalance;
  final double totalEarned;
  final double totalDeducted;
  final double totalApplied;

  /// Total credit remaining: opening + earned - deducted - applied.
  final double availableBalance;
}
