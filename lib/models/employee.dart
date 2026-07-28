class Employee {
  const Employee({
    required this.name,
    required this.officeName,
    required this.position,
    this.avatarUrl,
  });

  final String name;
  final String officeName;
  final String position;
  final String? avatarUrl;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}
