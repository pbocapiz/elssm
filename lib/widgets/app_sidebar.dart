import 'package:flutter/material.dart';

import '../models/employee.dart';
import '../theme.dart';

enum SidebarItem {
  dashboard,
  leaveBalance,
  payroll,
  profile,
  manageStartingCredits,
  leaveRecords,
  leaveCreditReport,
  members,
  terminalLeaveCalculator,
}

/// The SidebarItems grouped under the "Leave Credits" expandable menu in
/// the sidebar, instead of appearing as flat top-level items.
const leaveCreditsGroupItems = [
  SidebarItem.manageStartingCredits,
  SidebarItem.leaveRecords,
  SidebarItem.leaveCreditReport,
];

/// SidebarItems only shown to Admins and Approvers (accesslevel <= 2).
const _approverAndAdminOnlyItems = [...leaveCreditsGroupItems, SidebarItem.members];

extension SidebarItemDetails on SidebarItem {
  String get label => switch (this) {
    SidebarItem.dashboard => 'Dashboard',
    SidebarItem.leaveBalance => 'Leave Balance',
    SidebarItem.payroll => 'Payroll',
    SidebarItem.profile => 'Profile',
    SidebarItem.manageStartingCredits => 'Starting Credits',
    SidebarItem.leaveRecords => 'Leave Records',
    SidebarItem.leaveCreditReport => 'Credit Report',
    SidebarItem.members => 'Members',
    SidebarItem.terminalLeaveCalculator => 'Leave Calculator',
  };

  IconData get icon => switch (this) {
    SidebarItem.dashboard => Icons.dashboard_outlined,
    SidebarItem.leaveBalance => Icons.event_available_outlined,
    SidebarItem.payroll => Icons.payments_outlined,
    SidebarItem.profile => Icons.person_outline,
    SidebarItem.manageStartingCredits => Icons.edit_calendar_outlined,
    SidebarItem.leaveRecords => Icons.receipt_long_outlined,
    SidebarItem.leaveCreditReport => Icons.bar_chart_outlined,
    SidebarItem.members => Icons.group_outlined,
    SidebarItem.terminalLeaveCalculator => Icons.calculate_outlined,
  };

  IconData get selectedIcon => switch (this) {
    SidebarItem.dashboard => Icons.dashboard,
    SidebarItem.leaveBalance => Icons.event_available,
    SidebarItem.payroll => Icons.payments,
    SidebarItem.profile => Icons.person,
    SidebarItem.manageStartingCredits => Icons.edit_calendar,
    SidebarItem.leaveRecords => Icons.receipt_long,
    SidebarItem.leaveCreditReport => Icons.bar_chart,
    SidebarItem.members => Icons.group,
    SidebarItem.terminalLeaveCalculator => Icons.calculate,
  };
}

/// Sidebar items visible for a given accesslevel (1=Admin, 2=Approver,
/// 3=Employee). Only Admins and Approvers see the Leave Credits group
/// (Starting Credits, Leave Records, Credit Report) and Members. Profile
/// is excluded from this list -- it's still a valid SidebarItem (routed to
/// from the sidebar's user footer, see onTapProfile in _UserFooter), it's
/// just not shown as its own nav tile.
List<SidebarItem> sidebarItemsForAccessLevel(int accessLevel) => [
  for (final item in SidebarItem.values)
    if (item != SidebarItem.profile &&
        (!_approverAndAdminOnlyItems.contains(item) || accessLevel <= 2))
      item,
];

class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.employee,
    required this.items,
    required this.selected,
    required this.onSelect,
    required this.onLogout,
  });

  final Employee employee;
  final List<SidebarItem> items;
  final SidebarItem selected;
  final ValueChanged<SidebarItem> onSelect;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: navyBlue,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.transparent,
                    backgroundImage: AssetImage('assets/images/capiz_logo.png'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'ELSSM',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Employee Self-Service Leave Monitoring System',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.15)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                children: [
                  for (final item in items)
                    if (item == SidebarItem.manageStartingCredits)
                      _SidebarGroup(
                        label: 'Leave Credits',
                        icon: Icons.account_balance_wallet_outlined,
                        isExpandedInitially: leaveCreditsGroupItems.contains(
                          selected,
                        ),
                        children: [
                          for (final groupItem in leaveCreditsGroupItems)
                            _SidebarTile(
                              item: groupItem,
                              isSelected: groupItem == selected,
                              onTap: () => onSelect(groupItem),
                            ),
                        ],
                      )
                    else if (!leaveCreditsGroupItems.contains(item))
                      _SidebarTile(
                        item: item,
                        isSelected: item == selected,
                        onTap: () => onSelect(item),
                      ),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.15)),
            _UserFooter(
              employee: employee,
              onLogout: onLogout,
              onTapProfile: () => onSelect(SidebarItem.profile),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarGroup extends StatefulWidget {
  const _SidebarGroup({
    required this.label,
    required this.icon,
    required this.isExpandedInitially,
    required this.children,
  });

  final String label;
  final IconData icon;
  final bool isExpandedInitially;
  final List<Widget> children;

  @override
  State<_SidebarGroup> createState() => _SidebarGroupState();
}

class _SidebarGroupState extends State<_SidebarGroup> {
  late bool _expanded = widget.isExpandedInitially;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(widget.icon, size: 22, color: Colors.white70),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        widget.label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: Colors.white70,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Column(children: widget.children),
          ),
      ],
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final SidebarItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: isSelected ? taupe : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  isSelected ? item.selectedIcon : item.icon,
                  size: 22,
                  color: isSelected ? navyBlue : Colors.white70,
                ),
                const SizedBox(width: 14),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? navyBlue : Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserFooter extends StatelessWidget {
  const _UserFooter({
    required this.employee,
    required this.onLogout,
    required this.onTapProfile,
  });

  final Employee employee;
  final VoidCallback onLogout;
  final VoidCallback onTapProfile;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTapProfile,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: taupe,
                      backgroundImage: employee.avatarUrl != null
                          ? NetworkImage(employee.avatarUrl!)
                          : null,
                      child: employee.avatarUrl == null
                          ? Text(
                              employee.initials,
                              style: const TextStyle(
                                color: navyBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            employee.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            employee.officeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                          Text(
                            employee.position,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onLogout,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.logout, size: 20, color: Colors.redAccent),
                    const SizedBox(width: 14),
                    Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.redAccent.shade100,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
