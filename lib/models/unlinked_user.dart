class UnlinkedUser {
  const UnlinkedUser({
    required this.seqid,
    required this.id,
    required this.fullName,
  });

  factory UnlinkedUser.fromMap(Map<String, dynamic> map) => UnlinkedUser(
    seqid: map['seqid'] as int,
    id: map['id'] as String,
    fullName: (map['full_name'] as String?) ?? '',
  );

  final int seqid;
  final String id;
  final String fullName;
}
