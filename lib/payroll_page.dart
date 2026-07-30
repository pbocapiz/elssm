import 'package:flutter/material.dart';

import 'models/office_employee.dart';
import 'models/payroll_entry.dart';
import 'services/payroll_service.dart';
import 'theme.dart';

/// Formats with thousands separators for display only (e.g. "10,000.00")
/// -- never used on the editable quincena TextFields themselves, since
/// double.tryParse can't read a comma back out.
String _formatAmount(double value) {
  final fixed = value.toStringAsFixed(2);
  final parts = fixed.split('.');
  final whole = parts[0];
  final buffer = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    final fromEnd = whole.length - i;
    buffer.write(whole[i]);
    if (fromEnd > 1 && fromEnd % 3 == 1) buffer.write(',');
  }
  return '${buffer.toString()}.${parts[1]}';
}

/// Payroll screen: a year picker plus a 12-row (Jan-Dec) table of 1st/2nd
/// quincena amounts and their total. Employees (canEdit = false) can only
/// view their own; Approvers/Admins (canEdit = true) pick an employee from
/// their office (or any office, for Admins -- enforced by RLS) and enter
/// the amounts.
class PayrollPage extends StatefulWidget {
  const PayrollPage({super.key, required this.canEdit});

  final bool canEdit;

  @override
  State<PayrollPage> createState() => _PayrollPageState();
}

class _PayrollPageState extends State<PayrollPage> {
  int _selectedYear = DateTime.now().year;
  Future<List<OfficeEmployee>>? _employeesFuture;
  OfficeEmployee? _selectedEmployee;
  Future<List<PayrollEntry>>? _entriesFuture;

  final Map<int, TextEditingController> _firstControllers = {};
  final Map<int, TextEditingController> _secondControllers = {};
  final Set<int> _savingMonths = {};
  final Set<int> _savedMonths = {};
  final _defaultFirstController = TextEditingController();
  final _defaultSecondController = TextEditingController();
  bool _isSavingDefaults = false;
  bool _defaultsJustSaved = false;

  /// How long the check icon shows before reverting to the save icon.
  static const _savedIndicatorDuration = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    if (widget.canEdit) {
      _employeesFuture = PayrollService.fetchOfficeEmployees().then((
        employees,
      ) {
        if (employees.isNotEmpty && mounted) {
          setState(() => _selectedEmployee = employees.first);
          _syncDefaultFields();
          _loadEntries();
        }
        return employees;
      });
    } else {
      _loadEntries();
    }
  }

  @override
  void dispose() {
    for (final controller in _firstControllers.values) {
      controller.dispose();
    }
    for (final controller in _secondControllers.values) {
      controller.dispose();
    }
    _defaultFirstController.dispose();
    _defaultSecondController.dispose();
    super.dispose();
  }

  void _syncDefaultFields() {
    final first = _selectedEmployee?.defaultFirstQuincena;
    final second = _selectedEmployee?.defaultSecondQuincena;
    _defaultFirstController.text = first == null
        ? ''
        : first.toStringAsFixed(2);
    _defaultSecondController.text = second == null
        ? ''
        : second.toStringAsFixed(2);
  }

  void _loadEntries() {
    final Future<List<PayrollEntry>> future;
    if (widget.canEdit) {
      final employee = _selectedEmployee;
      if (employee == null) {
        future = Future.value(PayrollEntry.fillYear(const []));
      } else {
        future = PayrollService.fetchEmployeePayroll(
          employeeId: employee.employeeId,
          year: _selectedYear,
        );
      }
    } else {
      future = PayrollService.fetchOwnPayroll(_selectedYear);
    }

    final defaultFirst = _selectedEmployee?.defaultFirstQuincena;
    final defaultSecond = _selectedEmployee?.defaultSecondQuincena;

    setState(() {
      _entriesFuture = future.then((entries) {
        for (final entry in entries) {
          final double first;
          final double second;
          if (entry.hasSavedRow) {
            first = entry.firstQuincena;
            second = entry.secondQuincena;
          } else {
            // Never entered: pre-fill from each quincena's own default, so
            // whoever enters payroll only edits it down for that month's
            // deduction instead of typing the full amount every time.
            first = defaultFirst ?? 0;
            second = defaultSecond ?? 0;
          }
          _controllerFor(_firstControllers, entry.month).text = first
              .toStringAsFixed(2);
          _controllerFor(_secondControllers, entry.month).text = second
              .toStringAsFixed(2);
        }
        return entries;
      });
    });
  }

  Future<void> _saveDefaults() async {
    final employee = _selectedEmployee;
    if (employee == null) return;

    final first = double.tryParse(_defaultFirstController.text.trim());
    final second = double.tryParse(_defaultSecondController.text.trim());
    if (first == null || first < 0 || second == null || second < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid amounts for both')),
      );
      return;
    }

    setState(() => _isSavingDefaults = true);
    try {
      await PayrollService.setEmployeeDefaults(
        employeeId: employee.employeeId,
        firstQuincena: first,
        secondQuincena: second,
      );
      if (!mounted) return;
      setState(() {
        _selectedEmployee = OfficeEmployee(
          employeeId: employee.employeeId,
          fullName: employee.fullName,
          employeeNo: employee.employeeNo,
          defaultFirstQuincena: first,
          defaultSecondQuincena: second,
        );
        _defaultsJustSaved = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Defaults saved for ${employee.fullName}')),
      );
      _loadEntries();
      Future.delayed(_savedIndicatorDuration, () {
        if (mounted) setState(() => _defaultsJustSaved = false);
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save: $error')));
    } finally {
      if (mounted) setState(() => _isSavingDefaults = false);
    }
  }

  /// Creates the controller for [month] on first use and wires a listener
  /// so every keystroke triggers a rebuild -- that's what makes each row's
  /// total and the year total react live instead of only updating after a
  /// save-and-reload round trip.
  TextEditingController _controllerFor(
    Map<int, TextEditingController> controllers,
    int month,
  ) {
    return controllers.putIfAbsent(month, () {
      final controller = TextEditingController();
      controller.addListener(() => setState(() {}));
      return controller;
    });
  }

  Future<void> _save(int month) async {
    final employee = _selectedEmployee;
    if (!widget.canEdit || employee == null) return;

    final first = double.tryParse(_firstControllers[month]?.text.trim() ?? '');
    final second = double.tryParse(
      _secondControllers[month]?.text.trim() ?? '',
    );
    if (first == null || second == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter valid amounts')));
      return;
    }

    setState(() => _savingMonths.add(month));
    try {
      await PayrollService.setPayrollEntry(
        employeeId: employee.employeeId,
        year: _selectedYear,
        month: month,
        firstQuincena: first,
        secondQuincena: second,
      );
      if (!mounted) return;
      setState(() => _savedMonths.add(month));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${PayrollEntry.monthNames[month - 1]} saved')),
      );
      _loadEntries();
      Future.delayed(_savedIndicatorDuration, () {
        if (mounted) setState(() => _savedMonths.remove(month));
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save: $error')));
    } finally {
      if (mounted) setState(() => _savingMonths.remove(month));
    }
  }

  static const _fieldFill = Color(0xFFF1F2F5);

  InputDecoration _fieldDecoration(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: _fieldFill,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            children: [
              if (widget.canEdit) ...[
                Expanded(
                  child: FutureBuilder<List<OfficeEmployee>>(
                    future: _employeesFuture,
                    builder: (context, snapshot) {
                      final employees = snapshot.data ?? const [];
                      return DropdownButtonFormField<OfficeEmployee>(
                        initialValue: _selectedEmployee,
                        isExpanded: true,
                        decoration: _fieldDecoration('Employee'),
                        items: [
                          for (final employee in employees)
                            DropdownMenuItem(
                              value: employee,
                              child: Text(employee.fullName),
                            ),
                        ],
                        onChanged: (employee) {
                          setState(() => _selectedEmployee = employee);
                          _syncDefaultFields();
                          _loadEntries();
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
              ],
              SizedBox(
                width: 120,
                child: DropdownButtonFormField<int>(
                  initialValue: _selectedYear,
                  decoration: _fieldDecoration('Year'),
                  items: [
                    for (var y = currentYear - 2; y <= currentYear + 1; y++)
                      DropdownMenuItem(value: y, child: Text('$y')),
                  ],
                  onChanged: (year) {
                    if (year == null) return;
                    setState(() => _selectedYear = year);
                    _loadEntries();
                  },
                ),
              ),
            ],
          ),
        ),
        if (widget.canEdit && _selectedEmployee != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _defaultFirstController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: _fieldDecoration(
                      'Default 1st Quincena',
                    ).copyWith(prefixText: '₱ '),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _defaultSecondController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: _fieldDecoration(
                      'Default 2nd Quincena',
                    ).copyWith(prefixText: '₱ '),
                  ),
                ),
                const SizedBox(width: 12),
                _isSavingDefaults
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : FilledButton.icon(
                        onPressed: _saveDefaults,
                        style: FilledButton.styleFrom(
                          backgroundColor: _defaultsJustSaved
                              ? Colors.green.shade600
                              : navyBlue,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: Icon(
                          _defaultsJustSaved
                              ? Icons.check_rounded
                              : Icons.save_outlined,
                          size: 18,
                        ),
                        label: Text(_defaultsJustSaved ? 'Saved' : 'Save'),
                      ),
              ],
            ),
          ),
        Expanded(
          child: _entriesFuture == null
              ? const Center(child: CircularProgressIndicator())
              : FutureBuilder<List<PayrollEntry>>(
                  future: _entriesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Could not load payroll.\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      );
                    }

                    final entries = snapshot.data ?? const [];
                    if (widget.canEdit && _selectedEmployee == null) {
                      return Center(
                        child: Text(
                          'No employees found for your office.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      );
                    }

                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.canEdit) ...[
                            const _SavedStateLegend(),
                            const SizedBox(height: 8),
                          ],
                          _PayrollCard(
                            entries: entries,
                            canEdit: widget.canEdit,
                            firstControllers: _firstControllers,
                            secondControllers: _secondControllers,
                            savingMonths: _savingMonths,
                            savedMonths: _savedMonths,
                            onSave: _save,
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _SavedStateLegend extends StatelessWidget {
  const _SavedStateLegend();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.check_circle_rounded,
          size: 14,
          color: Colors.green.shade600,
        ),
        const SizedBox(width: 6),
        Text(
          'Saved',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(width: 16),
        Icon(Icons.circle_outlined, size: 14, color: Colors.grey.shade400),
        const SizedBox(width: 6),
        Text(
          'Not yet saved (default suggestion)',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

class _PayrollCard extends StatelessWidget {
  const _PayrollCard({
    required this.entries,
    required this.canEdit,
    required this.firstControllers,
    required this.secondControllers,
    required this.savingMonths,
    required this.savedMonths,
    required this.onSave,
  });

  final List<PayrollEntry> entries;
  final bool canEdit;
  final Map<int, TextEditingController> firstControllers;
  final Map<int, TextEditingController> secondControllers;
  final Set<int> savingMonths;
  final Set<int> savedMonths;
  final ValueChanged<int> onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: navyBlue.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      // LayoutBuilder gives the table a floor of "however wide this card
      // actually is" -- on a wide screen the table stretches to fill it
      // instead of hugging its own content width with dead space beside
      // it; on a narrow screen the content is wider than that floor, so
      // the horizontal scroll still kicks in exactly as before.
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: _PayrollTable(
                entries: entries,
                canEdit: canEdit,
                firstControllers: firstControllers,
                secondControllers: secondControllers,
                savingMonths: savingMonths,
                savedMonths: savedMonths,
                onSave: onSave,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PayrollTable extends StatelessWidget {
  const _PayrollTable({
    required this.entries,
    required this.canEdit,
    required this.firstControllers,
    required this.secondControllers,
    required this.savingMonths,
    required this.savedMonths,
    required this.onSave,
  });

  final List<PayrollEntry> entries;
  final bool canEdit;
  final Map<int, TextEditingController> firstControllers;
  final Map<int, TextEditingController> secondControllers;
  final Set<int> savingMonths;
  final Set<int> savedMonths;
  final ValueChanged<int> onSave;

  static const _fieldFill = Color(0xFFF1F2F5);

  /// The value driving every total in this table: the live text field
  /// content when editable (so totals react as you type), the fetched
  /// amount otherwise (view-only mode has no fields to react to).
  double _liveFirst(PayrollEntry entry) => canEdit
      ? (double.tryParse(firstControllers[entry.month]?.text.trim() ?? '') ?? 0)
      : entry.firstQuincena;

  double _liveSecond(PayrollEntry entry) => canEdit
      ? (double.tryParse(secondControllers[entry.month]?.text.trim() ?? '') ??
            0)
      : entry.secondQuincena;

  @override
  Widget build(BuildContext context) {
    final totalFirst = entries.fold<double>(0, (sum, e) => sum + _liveFirst(e));
    final totalSecond = entries.fold<double>(
      0,
      (sum, e) => sum + _liveSecond(e),
    );

    return DataTable(
      headingRowColor: WidgetStateProperty.all(navyBlue),
      headingTextStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
      dividerThickness: 0,
      columnSpacing: 28,
      horizontalMargin: 20,
      headingRowHeight: 52,
      dataRowMinHeight: 56,
      dataRowMaxHeight: 56,
      columns: [
        const DataColumn(label: Text('Month')),
        const DataColumn(label: Text('1st Quincena'), numeric: true),
        const DataColumn(label: Text('2nd Quincena'), numeric: true),
        const DataColumn(label: Text('Total'), numeric: true),
        if (canEdit) const DataColumn(label: Text('')),
      ],
      rows: [
        for (final (index, entry) in entries.indexed)
          DataRow(
            color: WidgetStateProperty.all(
              index.isEven ? Colors.white : navyBlue.withValues(alpha: 0.03),
            ),
            cells: [
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (canEdit) ...[
                      Tooltip(
                        message: entry.hasSavedRow
                            ? 'Saved to database'
                            : 'Not yet saved -- showing default suggestion',
                        child: Icon(
                          entry.hasSavedRow
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          size: 14,
                          color: entry.hasSavedRow
                              ? Colors.green.shade600
                              : Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      entry.monthName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: navyBlue,
                      ),
                    ),
                  ],
                ),
              ),
              DataCell(
                canEdit
                    ? SizedBox(
                        width: 110,
                        child: TextField(
                          controller: firstControllers[entry.month],
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textAlign: TextAlign.right,
                          decoration: InputDecoration(
                            isDense: true,
                            filled: true,
                            fillColor: _fieldFill,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      )
                    : Text(_formatAmount(entry.firstQuincena)),
              ),
              DataCell(
                canEdit
                    ? SizedBox(
                        width: 110,
                        child: TextField(
                          controller: secondControllers[entry.month],
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textAlign: TextAlign.right,
                          decoration: InputDecoration(
                            isDense: true,
                            filled: true,
                            fillColor: _fieldFill,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      )
                    : Text(_formatAmount(entry.secondQuincena)),
              ),
              DataCell(
                Text(
                  _formatAmount(_liveFirst(entry) + _liveSecond(entry)),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: navyBlue,
                  ),
                ),
              ),
              if (canEdit)
                DataCell(
                  savingMonths.contains(entry.month)
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : savedMonths.contains(entry.month)
                      ? Container(
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(
                              Icons.check_rounded,
                              color: Colors.green,
                              size: 18,
                            ),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: navyBlue.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.save_outlined,
                              color: navyBlue,
                              size: 18,
                            ),
                            splashRadius: 18,
                            onPressed: () => onSave(entry.month),
                          ),
                        ),
                ),
            ],
          ),
        DataRow(
          color: WidgetStateProperty.all(taupe.withValues(alpha: 0.22)),
          cells: [
            const DataCell(
              Text(
                'Total',
                style: TextStyle(fontWeight: FontWeight.bold, color: navyBlue),
              ),
            ),
            DataCell(
              Text(
                _formatAmount(totalFirst),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: navyBlue,
                ),
              ),
            ),
            DataCell(
              Text(
                _formatAmount(totalSecond),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: navyBlue,
                ),
              ),
            ),
            DataCell(
              Text(
                _formatAmount(totalFirst + totalSecond),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: navyBlue,
                ),
              ),
            ),
            if (canEdit) const DataCell(Text('')),
          ],
        ),
      ],
    );
  }
}
