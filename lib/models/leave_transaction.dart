enum LeaveTransactionType { openingBalance, credit, deduction, application }

class LeaveTransaction {
  const LeaveTransaction({
    required this.employeeId,
    required this.employeeName,
    required this.leaveTypeId,
    required this.leaveTypeName,
    required this.type,
    required this.date,
    required this.amount,
    this.status,
    this.remarks,
    this.sourceId,
  });

  factory LeaveTransaction.fromMap(Map<String, dynamic> map) {
    final typeString = map['transaction_type'] as String;
    final type = switch (typeString) {
      'OPENING_BALANCE' => LeaveTransactionType.openingBalance,
      'CREDIT' => LeaveTransactionType.credit,
      'DEDUCTION' => LeaveTransactionType.deduction,
      _ => LeaveTransactionType.application,
    };

    return LeaveTransaction(
      employeeId: map['employee_id'] as int,
      employeeName: (map['employee_name'] as String?) ?? '',
      leaveTypeId: map['leave_type_id'] as int,
      leaveTypeName: map['leave_type_name'] as String,
      type: type,
      date: DateTime.parse(map['transaction_date'] as String),
      amount: double.parse(map['amount'].toString()),
      status: map['status'] as String?,
      remarks: map['remarks'] as String?,
      sourceId: map['source_id'] as int?,
    );
  }

  final int employeeId;
  final String employeeName;
  final int leaveTypeId;
  final String leaveTypeName;
  final LeaveTransactionType type;
  final DateTime date;
  final double amount;
  final String? status;
  final String? remarks;

  /// The row id in this transaction's own source table (els_leave_credits,
  /// els_leave_deductions, els_leave_opening_balance, or
  /// els_leave_applications depending on [type]). Needed to target
  /// approve/reject, edit, and delete actions at the right row.
  final int? sourceId;
}
