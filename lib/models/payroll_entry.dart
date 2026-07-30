class PayrollEntry {
  const PayrollEntry({
    required this.month,
    required this.firstQuincena,
    required this.secondQuincena,
    this.hasSavedRow = true,
  });

  factory PayrollEntry.fromMap(Map<String, dynamic> map) {
    double asDouble(Object? value) =>
        value == null ? 0 : double.parse(value.toString());

    return PayrollEntry(
      month: map['month'] as int,
      firstQuincena: asDouble(map['first_quincena']),
      secondQuincena: asDouble(map['second_quincena']),
    );
  }

  /// One entry per calendar month, defaulting to zero (hasSavedRow: false)
  /// for months with no row yet -- callers always get all 12 back
  /// regardless of what's saved. hasSavedRow distinguishes "never entered"
  /// from "entered and deliberately zero", so a default salary can pre-fill
  /// the former without ever clobbering the latter.
  static List<PayrollEntry> fillYear(List<PayrollEntry> saved) {
    final byMonth = {for (final entry in saved) entry.month: entry};
    return [
      for (var month = 1; month <= 12; month++)
        byMonth[month] ??
            PayrollEntry(
              month: month,
              firstQuincena: 0,
              secondQuincena: 0,
              hasSavedRow: false,
            ),
    ];
  }

  final int month;
  final double firstQuincena;
  final double secondQuincena;

  /// False when this entry was synthesized by [fillYear] for a month with
  /// no els_payroll row at all, rather than fetched from a real one.
  final bool hasSavedRow;

  double get total => firstQuincena + secondQuincena;

  static const monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  String get monthName => monthNames[month - 1];

  /// Abbreviated for the payroll table, which needs Month, 1st, 2nd, Total,
  /// and a save button to all fit on a narrow screen without scrolling.
  String get monthShortName => monthName.substring(0, 3);
}
