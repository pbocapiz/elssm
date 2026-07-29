class LeaveType {
  const LeaveType({required this.id, required this.name});

  factory LeaveType.fromMap(Map<String, dynamic> map) =>
      LeaveType(id: map['id'] as int, name: map['leave_name'] as String);

  final int id;
  final String name;
}
