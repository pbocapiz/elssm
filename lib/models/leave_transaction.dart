enum LeaveTransactionType { openingBalance, credit, deduction, application }

class LeaveTransaction {
  const LeaveTransaction({
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

  final String employeeName;
  final int leaveTypeId;
  final String leaveTypeName;
  final LeaveTransactionType type;
  final DateTime date;
  final double amount;
  final String? status;
  final String? remarks;

  /// els_leave_applications.id when [type] is application, else null.
  /// Needed to target the approve/reject update.
  final int? sourceId;
}
