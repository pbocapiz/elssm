import 'package:flutter/material.dart';

import 'models/leave_credit_report_row.dart';
import 'services/leave_credit_report_service.dart';
import 'theme.dart';

class LeaveCreditReportPage extends StatefulWidget {
  const LeaveCreditReportPage({super.key});

  @override
  State<LeaveCreditReportPage> createState() => _LeaveCreditReportPageState();
}

class _LeaveCreditReportPageState extends State<LeaveCreditReportPage> {
  int _selectedYear = DateTime.now().year;
  int? _selectedEmployeeId;
  int? _selectedLeaveTypeId;

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

              final rows = (snapshot.data ?? const [])
                  .where(
                    (row) =>
                        (_selectedEmployeeId == null ||
                        row.employeeId == _selectedEmployeeId) &&
                        (_selectedLeaveTypeId == null ||
                        row.leaveTypeId == _selectedLeaveTypeId),
                  )
                  .toList();

              if (rows.isEmpty) {
                return Center(
                  child: Text(
                    'No leave credit records match your filters.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: rows.length,
                separatorBuilder: (context, index) =>
                    const Divider(height: 1),
                itemBuilder: (context, index) => _ReportRowTile(row: rows[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ReportRowTile extends StatelessWidget {
  const _ReportRowTile({required this.row});

  final LeaveCreditReportRow row;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.fullName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  row.leaveTypeName,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                row.availableBalance.toStringAsFixed(3),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: navyBlue,
                  fontSize: 16,
                ),
              ),
              Text(
                'days remaining',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
