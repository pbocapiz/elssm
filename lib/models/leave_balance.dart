class LeaveBalance {
  const LeaveBalance({
    required this.leaveTypeId,
    required this.leaveTypeName,
    required this.monthlyCredit,
    required this.openingBalance,
    required this.totalEarned,
    required this.totalDeducted,
    required this.totalApplied,
    required this.availableBalance,
  });

  factory LeaveBalance.fromMap(Map<String, dynamic> map) {
    double asDouble(Object? value) =>
        value == null ? 0 : double.parse(value.toString());

    return LeaveBalance(
      leaveTypeId: map['leave_type_id'] as int,
      leaveTypeName: map['leave_type_name'] as String,
      monthlyCredit: asDouble(map['monthly_credit']),
      openingBalance: asDouble(map['opening_balance']),
      totalEarned: asDouble(map['total_earned']),
      totalDeducted: asDouble(map['total_deducted']),
      totalApplied: asDouble(map['total_applied']),
      availableBalance: asDouble(map['available_balance']),
    );
  }

  final int leaveTypeId;
  final String leaveTypeName;
  final double monthlyCredit;
  final double openingBalance;
  final double totalEarned;
  final double totalDeducted;
  final double totalApplied;
  final double availableBalance;

  /// Short badge text derived from the name (e.g. "Vacation Leave" -> "VL"),
  /// since the source table has no dedicated short-code column.
  String get abbreviation {
    final words = leaveTypeName
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && w.toLowerCase() != 'leave');
    if (words.isEmpty) return leaveTypeName.substring(0, 1).toUpperCase();
    return words.map((w) => w[0].toUpperCase()).take(3).join();
  }
}
