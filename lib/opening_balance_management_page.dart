import 'package:flutter/material.dart';

import 'models/leave_type.dart';
import 'models/office_employee_balance.dart';
import 'models/unlinked_user.dart';
import 'services/employee_service.dart';
import 'services/opening_balance_service.dart';
import 'theme.dart';

class OpeningBalanceManagementPage extends StatefulWidget {
  const OpeningBalanceManagementPage({super.key});

  @override
  State<OpeningBalanceManagementPage> createState() =>
      _OpeningBalanceManagementPageState();
}

class _OpeningBalanceManagementPageState
    extends State<OpeningBalanceManagementPage> {
  late Future<List<LeaveType>> _leaveTypesFuture;
  LeaveType? _selectedLeaveType;
  int _selectedYear = DateTime.now().year;

  Future<List<OfficeEmployeeBalance>>? _balancesFuture;
  final Map<int, TextEditingController> _controllers = {};
  final Set<int> _savingEmployeeIds = {};

  @override
  void initState() {
    super.initState();
    _leaveTypesFuture = OpeningBalanceService.fetchLeaveTypes().then((types) {
      if (types.isNotEmpty && mounted) {
        setState(() => _selectedLeaveType = types.first);
        _loadBalances();
      }
      return types;
    });
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _loadBalances() {
    final leaveType = _selectedLeaveType;
    if (leaveType == null) return;
    setState(() {
      _balancesFuture =
          OpeningBalanceService.fetchOpeningBalances(
            leaveTypeId: leaveType.id,
            year: _selectedYear,
          ).then((balances) {
            for (final balance in balances) {
              _controllers
                  .putIfAbsent(
                    balance.employeeId,
                    () => TextEditingController(),
                  )
                  .text = balance.openingBalance.toStringAsFixed(
                2,
              );
            }
            return balances;
          });
    });
  }

  Future<void> _save(OfficeEmployeeBalance balance) async {
    final leaveType = _selectedLeaveType;
    if (leaveType == null) return;

    final value = double.tryParse(
      _controllers[balance.employeeId]?.text.trim() ?? '',
    );
    if (value == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a valid number')));
      return;
    }

    setState(() => _savingEmployeeIds.add(balance.employeeId));
    try {
      await OpeningBalanceService.setOpeningBalance(
        employeeId: balance.employeeId,
        leaveTypeId: leaveType.id,
        year: _selectedYear,
        amount: value,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Updated ${balance.fullName}')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save: $error')));
    } finally {
      if (mounted) {
        setState(() => _savingEmployeeIds.remove(balance.employeeId));
      }
    }
  }

  Future<void> _openAddEmployeeDialog() async {
    final added = await showDialog<bool>(
      context: context,
      builder: (context) => const _AddEmployeeDialog(),
    );
    if (added == true) {
      _loadBalances();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: navyBlue,
        foregroundColor: Colors.white,
        tooltip: 'Add employee',
        onPressed: _openAddEmployeeDialog,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: FutureBuilder<List<LeaveType>>(
                    future: _leaveTypesFuture,
                    builder: (context, snapshot) {
                      final types = snapshot.data ?? const [];
                      return DropdownButtonFormField<LeaveType>(
                        initialValue: _selectedLeaveType,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Leave Type',
                        ),
                        items: [
                          for (final type in types)
                            DropdownMenuItem(
                              value: type,
                              child: Text(type.name),
                            ),
                        ],
                        onChanged: (type) {
                          setState(() => _selectedLeaveType = type);
                          _loadBalances();
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 110,
                  child: DropdownButtonFormField<int>(
                    initialValue: _selectedYear,
                    decoration: const InputDecoration(labelText: 'Year'),
                    items: [
                      for (var y = currentYear - 2; y <= currentYear + 1; y++)
                        DropdownMenuItem(value: y, child: Text('$y')),
                    ],
                    onChanged: (year) {
                      if (year == null) return;
                      setState(() => _selectedYear = year);
                      _loadBalances();
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _balancesFuture == null
                ? const Center(child: CircularProgressIndicator())
                : FutureBuilder<List<OfficeEmployeeBalance>>(
                    future: _balancesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Could not load employees.\n${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        );
                      }

                      final balances = snapshot.data ?? const [];
                      if (balances.isEmpty) {
                        return Center(
                          child: Text(
                            'No employees found for your office.',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: balances.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final balance = balances[index];
                          final isSaving = _savingEmployeeIds.contains(
                            balance.employeeId,
                          );

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        balance.fullName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (balance.employeeNo != null)
                                        Text(
                                          balance.employeeNo!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: 100,
                                  child: TextField(
                                    controller:
                                        _controllers[balance.employeeId],
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    textAlign: TextAlign.right,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                isSaving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : IconButton(
                                        icon: const Icon(
                                          Icons.save_outlined,
                                          color: navyBlue,
                                        ),
                                        onPressed: () => _save(balance),
                                      ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _AddEmployeeDialog extends StatefulWidget {
  const _AddEmployeeDialog();

  @override
  State<_AddEmployeeDialog> createState() => _AddEmployeeDialogState();
}

class _AddEmployeeDialogState extends State<_AddEmployeeDialog> {
  late Future<List<UnlinkedUser>> _unlinkedUsersFuture;
  final _employeeNoController = TextEditingController();
  UnlinkedUser? _selectedUser;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _unlinkedUsersFuture = EmployeeService.fetchUnlinkedUsers();
  }

  @override
  void dispose() {
    _employeeNoController.dispose();
    super.dispose();
  }

  Future<void> _handleAdd() async {
    final user = _selectedUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select a user first')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      await EmployeeService.addEmployee(
        usersId: user.seqid,
        employeeNo: _employeeNoController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add employee: $error')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Employee'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<List<UnlinkedUser>>(
              future: _unlinkedUsersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Text(
                    'Could not load users.\n${snapshot.error}',
                    style: TextStyle(color: Colors.grey.shade600),
                  );
                }

                final users = snapshot.data ?? const [];
                if (users.isEmpty) {
                  return Text(
                    'No unlinked employees left in your office — '
                    'everyone already has an employee record.',
                    style: TextStyle(color: Colors.grey.shade600),
                  );
                }

                return DropdownButtonFormField<UnlinkedUser>(
                  initialValue: _selectedUser,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'User'),
                  items: [
                    for (final user in users)
                      DropdownMenuItem(value: user, child: Text(user.fullName)),
                  ],
                  onChanged: (user) => setState(() => _selectedUser = user),
                );
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _employeeNoController,
              decoration: const InputDecoration(
                labelText: 'Employee No. (optional)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _handleAdd,
          style: FilledButton.styleFrom(backgroundColor: navyBlue),
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Add'),
        ),
      ],
    );
  }
}
