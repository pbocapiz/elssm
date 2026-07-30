import 'package:flutter/material.dart';

import 'models/leave_transaction.dart';
import 'services/member_service.dart';
import 'services/transaction_service.dart';
import 'theme.dart';
import 'widgets/app_sidebar.dart';

/// Approver/Admin-only strip shown above the Dashboard's own leave balance
/// cards: pending leave approvals and pending member activations, each
/// tappable straight through to the page that handles it.
class AdminOverviewSection extends StatefulWidget {
  const AdminOverviewSection({super.key, required this.onNavigate});

  final ValueChanged<SidebarItem> onNavigate;

  @override
  State<AdminOverviewSection> createState() => _AdminOverviewSectionState();
}

class _AdminOverviewSectionState extends State<AdminOverviewSection> {
  late Future<int> _pendingApprovalsFuture;
  late Future<int> _pendingMembersFuture;

  @override
  void initState() {
    super.initState();
    _pendingApprovalsFuture = _loadPendingApprovals();
    _pendingMembersFuture = _loadPendingMembers();
  }

  Future<int> _loadPendingApprovals() async {
    final transactions = await TransactionService.fetchOfficeTransactions();
    return transactions
        .where(
          (t) =>
              t.type == LeaveTransactionType.application &&
              t.status == 'PENDING',
        )
        .length;
  }

  Future<int> _loadPendingMembers() async {
    final members = await MemberService.fetchMembers();
    return members.where((m) => !m.isActive).length;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: FutureBuilder<int>(
              future: _pendingApprovalsFuture,
              builder: (context, snapshot) => _OverviewCard(
                icon: Icons.pending_actions_rounded,
                label: 'Pending Approvals',
                count: snapshot.data,
                onTap: () => widget.onNavigate(SidebarItem.leaveRecords),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FutureBuilder<int>(
              future: _pendingMembersFuture,
              builder: (context, snapshot) => _OverviewCard(
                icon: Icons.person_add_alt_1_rounded,
                label: 'Pending Members',
                count: snapshot.data,
                onTap: () => widget.onNavigate(SidebarItem.members),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int? count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasPending = (count ?? 0) > 0;
    final accentColor = hasPending ? Colors.orange.shade700 : navyBlue;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: navyBlue.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      count == null ? '–' : '$count',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
