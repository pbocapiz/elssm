import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_overview_section.dart';
import 'leave_balance_page.dart';
import 'leave_credit_report_page.dart';
import 'leave_history_page.dart';
import 'leave_records_page.dart';
import 'leave_report_export_page.dart';
import 'members_page.dart';
import 'models/employee.dart';
import 'opening_balance_management_page.dart';
import 'payroll_page.dart';
import 'profile_page.dart';
import 'services/profile_service.dart';
import 'terminal_leave_calculator_page.dart';
import 'theme.dart';
import 'widgets/app_sidebar.dart';

const _sidebarWidth = 271.0;

/// Keyed per user (not just a flat key) so a shared browser doesn't hand
/// one signed-in user's last-viewed page to whoever logs in next -- e.g.
/// an Approver leaving the Members page open shouldn't land an Employee
/// there after they sign in on the same machine.
String _lastPageKey(String userId) => 'elssm_last_page_$userId';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  SidebarItem _selected = SidebarItem.dashboard;

  static const _loadingEmployee = Employee(
    name: 'Loading…',
    officeName: '',
    position: '',
  );
  Employee _employee = _loadingEmployee;

  @override
  void initState() {
    super.initState();
    _loadEmployee();
    _restoreLastSelected();
  }

  Future<void> _loadEmployee() async {
    final employee = await ProfileService.fetchCurrentEmployee();
    if (mounted && employee != null) {
      setState(() => _employee = employee);
    }
  }

  Future<void> _restoreLastSelected() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString(_lastPageKey(userId));
    if (savedName == null || !mounted) return;

    for (final item in SidebarItem.values) {
      if (item.name == savedName) {
        setState(() => _selected = item);
        break;
      }
    }
  }

  void _selectItem(SidebarItem item) {
    setState(() => _selected = item);
    _scaffoldKey.currentState?.closeDrawer();
    _persistSelected(item);
  }

  Future<void> _persistSelected(SidebarItem item) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastPageKey(userId), item.name);
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const _LogoutDialog(),
    );

    if (confirmed == true) {
      await Supabase.instance.client.auth.signOut();
      // No manual navigation: AuthGate listens for the auth state change
      // and swaps back to LoginPage on its own.
    }
  }

  @override
  Widget build(BuildContext context) {
    final sidebar = AppSidebar(
      employee: _employee,
      items: sidebarItemsForAccessLevel(_employee.accessLevel),
      selected: _selected,
      onSelect: _selectItem,
      onLogout: _handleLogout,
    );

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: navyBlue,
        foregroundColor: Colors.white,
        title: Text(_selected.label),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Menu',
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
      ),
      drawer: Drawer(width: _sidebarWidth, child: sidebar),
      body: _ContentArea(
        selected: _selected,
        accessLevel: _employee.accessLevel,
        onNavigate: _selectItem,
      ),
    );
  }
}

class _ContentArea extends StatelessWidget {
  const _ContentArea({
    required this.selected,
    required this.accessLevel,
    required this.onNavigate,
  });

  final SidebarItem selected;
  final int accessLevel;
  final ValueChanged<SidebarItem> onNavigate;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (selected == SidebarItem.dashboard) {
      return Container(
        color: colorScheme.surface,
        child: Column(
          children: [
            if (accessLevel <= 2) AdminOverviewSection(onNavigate: onNavigate),
            const Expanded(child: LeaveBalancePage()),
          ],
        ),
      );
    }

    if (selected == SidebarItem.leaveBalance) {
      return Container(
        color: colorScheme.surface,
        child: const LeaveHistoryPage(),
      );
    }

    if (selected == SidebarItem.manageStartingCredits) {
      return Container(
        color: colorScheme.surface,
        child: const OpeningBalanceManagementPage(),
      );
    }

    if (selected == SidebarItem.leaveRecords) {
      return Container(
        color: colorScheme.surface,
        child: const LeaveRecordsPage(),
      );
    }

    if (selected == SidebarItem.leaveCreditReport) {
      return Container(
        color: colorScheme.surface,
        child: const LeaveCreditReportPage(),
      );
    }

    if (selected == SidebarItem.reports) {
      return Container(
        color: colorScheme.surface,
        child: const LeaveReportExportPage(),
      );
    }

    if (selected == SidebarItem.members) {
      return Container(
        color: colorScheme.surface,
        child: MembersPage(accessLevel: accessLevel),
      );
    }

    if (selected == SidebarItem.profile) {
      return Container(color: colorScheme.surface, child: const ProfilePage());
    }

    if (selected == SidebarItem.terminalLeaveCalculator) {
      return Container(
        color: colorScheme.surface,
        child: const TerminalLeaveCalculatorPage(),
      );
    }

    if (selected == SidebarItem.payroll) {
      return Container(
        color: colorScheme.surface,
        child: PayrollPage(canEdit: accessLevel <= 2),
      );
    }

    return Container(
      color: colorScheme.surface,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected.selectedIcon, size: 56, color: colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              selected.label,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoutDialog extends StatelessWidget {
  const _LogoutDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withValues(alpha: 0.1),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Colors.redAccent,
                  size: 22,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Log Out?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: navyBlue,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "You'll need to sign in again to access your account.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: navyBlue,
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Log Out',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
