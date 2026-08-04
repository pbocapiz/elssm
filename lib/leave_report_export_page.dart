import 'dart:typed_data';

import 'package:excel/excel.dart' hide Border, BorderStyle;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';

import 'models/leave_credit_report_row.dart';
import 'models/member.dart';
import 'services/leave_credit_report_service.dart';
import 'services/member_service.dart';
import 'theme.dart';

/// Admin/Approver screen for exporting reports to .xlsx files the
/// browser/OS downloads to the device: leave credits (reusing the Credit
/// Report screen's data/filters) and user information (reusing the
/// Members screen's data).
class LeaveReportExportPage extends StatelessWidget {
  const LeaveReportExportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              labelColor: navyBlue,
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: navyBlue,
              tabs: const [
                Tab(text: 'Leave Credits'),
                Tab(text: 'User Information'),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [_LeaveCreditReportTab(), _UserInformationReportTab()],
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaveCreditReportTab extends StatefulWidget {
  const _LeaveCreditReportTab();

  @override
  State<_LeaveCreditReportTab> createState() => _LeaveCreditReportTabState();
}

class _LeaveCreditReportTabState extends State<_LeaveCreditReportTab> {
  int _selectedYear = DateTime.now().year;
  int? _selectedEmployeeId;
  int? _selectedLeaveTypeId;
  bool _isExporting = false;

  late Future<List<LeaveCreditReportRow>> _reportFuture;

  @override
  void initState() {
    super.initState();
    _reportFuture = LeaveCreditReportService.fetchReport(year: _selectedYear);
  }

  void _reload() {
    setState(() {
      _reportFuture = LeaveCreditReportService.fetchReport(
        year: _selectedYear,
      );
      _selectedEmployeeId = null;
      _selectedLeaveTypeId = null;
    });
  }

  List<LeaveCreditReportRow> _filtered(List<LeaveCreditReportRow> rows) {
    return rows
        .where(
          (row) =>
              (_selectedEmployeeId == null ||
              row.employeeId == _selectedEmployeeId) &&
              (_selectedLeaveTypeId == null ||
              row.leaveTypeId == _selectedLeaveTypeId),
        )
        .toList();
  }

  Future<void> _exportToExcel(List<LeaveCreditReportRow> rows) async {
    setState(() => _isExporting = true);
    try {
      final workbook = Excel.createExcel();
      const sheetName = 'Leave Credit Report';
      final sheet = workbook[sheetName];
      workbook.setDefaultSheet(sheetName);
      for (final name in [...workbook.sheets.keys]) {
        if (name != sheetName) workbook.delete(name);
      }

      sheet.appendRow([
        TextCellValue('Employee No.'),
        TextCellValue('Employee Name'),
        TextCellValue('Leave Type'),
        TextCellValue('Opening'),
        TextCellValue('Earned'),
        TextCellValue('Deducted'),
        TextCellValue('Applied'),
        TextCellValue('Available Balance'),
      ]);

      // Opening/Earned/Deducted/Applied/Available Balance columns (indices
      // 3-7) get a "0.000" cell format so Excel displays 3 decimal places,
      // matching the rest of the app, while staying real numeric cells
      // (not text) so sums/sorting still work in Excel.
      const numericColumns = [3, 4, 5, 6, 7];
      final threeDecimalStyle = CellStyle(
        numberFormat: NumFormat.custom(formatCode: '0.000'),
      );

      for (var i = 0; i < rows.length; i++) {
        final row = rows[i];
        final rowIndex = i + 1;
        sheet.appendRow([
          TextCellValue(row.employeeNo ?? ''),
          TextCellValue(row.fullName),
          TextCellValue(row.leaveTypeName),
          DoubleCellValue(row.openingBalance),
          DoubleCellValue(row.totalEarned),
          DoubleCellValue(row.totalDeducted),
          DoubleCellValue(row.totalApplied),
          DoubleCellValue(row.availableBalance),
        ]);
        for (final column in numericColumns) {
          sheet
              .cell(
                CellIndex.indexByColumnRow(
                  columnIndex: column,
                  rowIndex: rowIndex,
                ),
              )
              .cellStyle = threeDecimalStyle;
        }
      }

      final bytes = workbook.save();
      if (bytes == null) {
        throw StateError('Could not generate the Excel file');
      }

      await FileSaver.instance.saveFile(
        name: 'leave_credit_report_$_selectedYear',
        bytes: Uint8List.fromList(bytes),
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Excel report saved')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to export: $error')));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: FutureBuilder<List<LeaveCreditReportRow>>(
            future: _reportFuture,
            builder: (context, snapshot) {
              final rows = snapshot.data ?? const [];

              final employees = <int, String>{};
              final leaveTypes = <int, String>{};
              for (final row in rows) {
                employees[row.employeeId] = row.fullName;
                leaveTypes[row.leaveTypeId] = row.leaveTypeName;
              }
              final employeeEntries = employees.entries.toList()
                ..sort((a, b) => a.value.compareTo(b.value));
              final leaveTypeEntries = leaveTypes.entries.toList()
                ..sort((a, b) => a.value.compareTo(b.value));

              final filteredCount = _filtered(rows).length;

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int?>(
                          initialValue: _selectedEmployeeId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Filter by User',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('All Users'),
                            ),
                            for (final entry in employeeEntries)
                              DropdownMenuItem(
                                value: entry.key,
                                child: Text(
                                  entry.value,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (id) =>
                              setState(() => _selectedEmployeeId = id),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int?>(
                          initialValue: _selectedLeaveTypeId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Filter by Leave Type',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('All Leave Types'),
                            ),
                            for (final entry in leaveTypeEntries)
                              DropdownMenuItem(
                                value: entry.key,
                                child: Text(
                                  entry.value,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (id) =>
                              setState(() => _selectedLeaveTypeId = id),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _selectedYear,
                          decoration: const InputDecoration(
                            labelText: 'Year',
                          ),
                          items: [
                            for (
                              var y = currentYear - 2;
                              y <= currentYear + 1;
                              y++
                            )
                              DropdownMenuItem(value: y, child: Text('$y')),
                          ],
                          onChanged: (year) {
                            if (year == null) return;
                            setState(() => _selectedYear = year);
                            _reload();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: (_isExporting || filteredCount == 0)
                          ? null
                          : () => _exportToExcel(_filtered(rows)),
                      style: FilledButton.styleFrom(
                        backgroundColor: navyBlue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: _isExporting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.file_download_outlined),
                      label: Text(
                        _isExporting
                            ? 'Exporting…'
                            : 'Export $filteredCount row(s) to Excel',
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<List<LeaveCreditReportRow>>(
            future: _reportFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Could not load the report.\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                );
              }

              final rows = _filtered(snapshot.data ?? const []);

              if (rows.isEmpty) {
                return Center(
                  child: Text(
                    'No leave credit records match your filters.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                );
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth,
                        ),
                        child: DataTable(
                          headingRowHeight: 72,
                          headingRowColor: WidgetStateProperty.all(
                            navyBlue.withValues(alpha: 0.06),
                          ),
                          headingTextStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                            color: Colors.grey.shade600,
                          ),
                          dataTextStyle: const TextStyle(
                            fontSize: 13,
                            color: navyBlue,
                          ),
                          columns: const [
                            DataColumn(label: Text('EMPLOYEE')),
                            DataColumn(
                              label: _TwoLineColumnLabel('LEAVE', 'TYPE'),
                            ),
                            DataColumn(label: Text('OPENING'), numeric: true),
                            DataColumn(label: Text('EARNED'), numeric: true),
                            DataColumn(
                              label: Text('DEDUCTED'),
                              numeric: true,
                            ),
                            DataColumn(label: Text('APPLIED'), numeric: true),
                            DataColumn(label: Text('TOTAL'), numeric: true),
                          ],
                          rows: [
                            for (final row in rows)
                              DataRow(
                                cells: [
                                  DataCell(Text(row.fullName)),
                                  DataCell(Text(row.leaveTypeName)),
                                  DataCell(
                                    Text(
                                      row.openingBalance.toStringAsFixed(3),
                                    ),
                                  ),
                                  DataCell(
                                    Text(row.totalEarned.toStringAsFixed(3)),
                                  ),
                                  DataCell(
                                    Text(
                                      row.totalDeducted.toStringAsFixed(3),
                                    ),
                                  ),
                                  DataCell(
                                    Text(row.totalApplied.toStringAsFixed(3)),
                                  ),
                                  DataCell(
                                    Text(
                                      row.availableBalance.toStringAsFixed(3),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _UserInformationReportTab extends StatefulWidget {
  const _UserInformationReportTab();

  @override
  State<_UserInformationReportTab> createState() =>
      _UserInformationReportTabState();
}

class _UserInformationReportTabState
    extends State<_UserInformationReportTab> {
  int? _selectedAccessLevel;
  bool _isExporting = false;

  late Future<List<Member>> _membersFuture;

  @override
  void initState() {
    super.initState();
    _membersFuture = MemberService.fetchMembers();
  }

  List<Member> _filtered(List<Member> members) {
    if (_selectedAccessLevel == null) return members;
    return members
        .where((member) => member.accessLevel == _selectedAccessLevel)
        .toList();
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _exportToExcel(List<Member> members) async {
    setState(() => _isExporting = true);
    try {
      final workbook = Excel.createExcel();
      const sheetName = 'User Information';
      final sheet = workbook[sheetName];
      workbook.setDefaultSheet(sheetName);
      for (final name in [...workbook.sheets.keys]) {
        if (name != sheetName) workbook.delete(name);
      }

      sheet.appendRow([
        TextCellValue('Employee No.'),
        TextCellValue('First Name'),
        TextCellValue('Middle Name'),
        TextCellValue('Last Name'),
        TextCellValue('Suffix'),
        TextCellValue('Email'),
        TextCellValue('Position'),
        TextCellValue('Office'),
        TextCellValue('Access Level'),
        TextCellValue('Status'),
        TextCellValue('Employment Status'),
        TextCellValue('Division/Section'),
        TextCellValue('Immediate Supervisor'),
        TextCellValue('Civil Status'),
        TextCellValue('GSIS No.'),
        TextCellValue('TIN No.'),
        TextCellValue('Philhealth No.'),
        TextCellValue('Pag-IBIG No.'),
        TextCellValue('Date Hired'),
      ]);

      for (final member in members) {
        sheet.appendRow([
          TextCellValue(member.employeeNo ?? ''),
          TextCellValue(member.firstName),
          TextCellValue(member.middleName ?? ''),
          TextCellValue(member.lastName),
          TextCellValue(member.suffix ?? ''),
          TextCellValue(member.email),
          TextCellValue(member.position),
          TextCellValue(member.officeName),
          TextCellValue(member.accessLevelLabel),
          TextCellValue(member.isActive ? 'Active' : 'Pending'),
          TextCellValue(member.employmentStatus ?? ''),
          TextCellValue(member.divisionSection ?? ''),
          TextCellValue(member.immediateSupervisor ?? ''),
          TextCellValue(member.civilStatus ?? ''),
          TextCellValue(member.gsisNo ?? ''),
          TextCellValue(member.tinNo ?? ''),
          TextCellValue(member.philhealthNo ?? ''),
          TextCellValue(member.pagibigNo ?? ''),
          member.dateHired == null
              ? TextCellValue('')
              : DateCellValue.fromDateTime(member.dateHired!),
        ]);
      }

      final bytes = workbook.save();
      if (bytes == null) {
        throw StateError('Could not generate the Excel file');
      }

      await FileSaver.instance.saveFile(
        name: 'user_information_report',
        bytes: Uint8List.fromList(bytes),
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Excel report saved')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to export: $error')));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: FutureBuilder<List<Member>>(
            future: _membersFuture,
            builder: (context, snapshot) {
              final members = snapshot.data ?? const [];
              final filteredCount = _filtered(members).length;

              return Column(
                children: [
                  DropdownButtonFormField<int?>(
                    initialValue: _selectedAccessLevel,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Filter by Access Level',
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Everyone')),
                      DropdownMenuItem(value: 2, child: Text('Approver')),
                      DropdownMenuItem(value: 3, child: Text('Employee')),
                    ],
                    onChanged: (level) =>
                        setState(() => _selectedAccessLevel = level),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: (_isExporting || filteredCount == 0)
                          ? null
                          : () => _exportToExcel(_filtered(members)),
                      style: FilledButton.styleFrom(
                        backgroundColor: navyBlue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: _isExporting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.file_download_outlined),
                      label: Text(
                        _isExporting
                            ? 'Exporting…'
                            : 'Export $filteredCount user(s) to Excel',
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<List<Member>>(
            future: _membersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Could not load members.\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                );
              }

              final members = _filtered(snapshot.data ?? const []);

              if (members.isEmpty) {
                return Center(
                  child: Text(
                    'No members match your filters.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                );
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth,
                        ),
                        child: DataTable(
                          headingRowHeight: 72,
                          headingRowColor: WidgetStateProperty.all(
                            navyBlue.withValues(alpha: 0.06),
                          ),
                          headingTextStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                            color: Colors.grey.shade600,
                          ),
                          dataTextStyle: const TextStyle(
                            fontSize: 13,
                            color: navyBlue,
                          ),
                          columns: const [
                            DataColumn(label: Text('NAME')),
                            DataColumn(label: Text('POSITION')),
                            DataColumn(label: Text('OFFICE')),
                            DataColumn(label: Text('ACCESS LEVEL')),
                            DataColumn(label: Text('STATUS')),
                            DataColumn(label: Text('DATE HIRED')),
                          ],
                          rows: [
                            for (final member in members)
                              DataRow(
                                cells: [
                                  DataCell(Text(member.fullName)),
                                  DataCell(Text(member.position)),
                                  DataCell(Text(member.officeName)),
                                  DataCell(Text(member.accessLevelLabel)),
                                  DataCell(
                                    Text(
                                      member.isActive ? 'Active' : 'Pending',
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      member.dateHired == null
                                          ? '—'
                                          : _formatDate(member.dateHired!),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TwoLineColumnLabel extends StatelessWidget {
  const _TwoLineColumnLabel(this.top, this.bottom);

  final String top;
  final String bottom;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Text(top), Text(bottom)],
    );
  }
}
