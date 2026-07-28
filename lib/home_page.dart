import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/employee.dart';
import 'theme.dart';
import 'widgets/app_sidebar.dart';

const _wideLayoutBreakpoint = 800.0;
const _sidebarWidth = 260.0;
const _sidebarAnimationDuration = Duration(milliseconds: 260);
const _sidebarAnimationCurve = Curves.easeInOutCubic;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  SidebarItem _selected = SidebarItem.dashboard;
  bool _sidebarOpen = true;

  static const _employee = Employee(
    name: 'Juan Dela Cruz',
    officeName: 'Head Office',
    position: 'Software Engineer',
  );

  void _selectItem(SidebarItem item, {required bool isWide}) {
    setState(() {
      _selected = item;
      if (isWide) _sidebarOpen = false;
    });
    if (!isWide) {
      _scaffoldKey.currentState?.closeDrawer();
    }
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideLayoutBreakpoint;

        final sidebar = AppSidebar(
          employee: _employee,
          selected: _selected,
          onSelect: (item) => _selectItem(item, isWide: isWide),
          onLogout: _handleLogout,
        );

        return Scaffold(
          key: _scaffoldKey,
          appBar: AppBar(
            backgroundColor: navyBlue,
            foregroundColor: Colors.white,
            title: Text(_selected.label),
            leading: isWide
                ? IconButton(
                    icon: const Icon(Icons.menu),
                    tooltip: _sidebarOpen ? 'Hide sidebar' : 'Show sidebar',
                    onPressed: () =>
                        setState(() => _sidebarOpen = !_sidebarOpen),
                  )
                : null,
          ),
          drawer: isWide
              ? null
              : Drawer(width: _sidebarWidth, child: sidebar),
          body: Row(
            children: [
              if (isWide)
                AnimatedContainer(
                  duration: _sidebarAnimationDuration,
                  curve: _sidebarAnimationCurve,
                  width: _sidebarOpen ? _sidebarWidth : 0,
                  clipBehavior: Clip.hardEdge,
                  decoration: const BoxDecoration(),
                  child: OverflowBox(
                    minWidth: _sidebarWidth,
                    maxWidth: _sidebarWidth,
                    alignment: Alignment.centerLeft,
                    child: sidebar,
                  ),
                ),
              if (isWide && _sidebarOpen) const VerticalDivider(width: 1),
              Expanded(
                child: _ContentArea(selected: _selected),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ContentArea extends StatelessWidget {
  const _ContentArea({required this.selected});

  final SidebarItem selected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withValues(alpha: 0.1),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: Colors.redAccent,
                size: 30,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Log Out?',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: navyBlue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "You'll need to sign in again to access your account.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: navyBlue,
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Log Out',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
