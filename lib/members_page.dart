import 'package:flutter/material.dart';

import 'models/member.dart';
import 'services/member_service.dart';
import 'theme.dart';

class MembersPage extends StatefulWidget {
  const MembersPage({super.key});

  @override
  State<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
  late Future<List<Member>> _membersFuture;
  bool _pendingOnly = false;

  @override
  void initState() {
    super.initState();
    _membersFuture = MemberService.fetchMembers();
  }

  Future<void> _reload() {
    final future = MemberService.fetchMembers();
    setState(() {
      _membersFuture = future;
    });
    return future;
  }

  Future<void> _confirmActivate(Member member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Activate Member?'),
        content: Text(
          '${member.fullName} (${member.email}) will be able to sign in '
          'and use the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: navyBlue),
            child: const Text('Activate'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await MemberService.setActive(userId: member.id, isActive: true);
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${member.fullName} activated')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to activate: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FutureBuilder<List<Member>>(
        future: _membersFuture,
        builder: (context, snapshot) {
          final pendingCount = (snapshot.data ?? const [])
              .where((member) => !member.isActive)
              .length;

          final fab = FloatingActionButton(
            backgroundColor: navyBlue,
            foregroundColor: Colors.white,
            tooltip: _pendingOnly
                ? 'Show all members'
                : 'Show newly registered members',
            onPressed: () => setState(() => _pendingOnly = !_pendingOnly),
            child: const Icon(Icons.list_alt),
          );

          if (pendingCount == 0) return fab;
          return Badge(
            label: Text('$pendingCount'),
            backgroundColor: Colors.redAccent,
            child: fab,
          );
        },
      ),
      body: FutureBuilder<List<Member>>(
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

          final members = (snapshot.data ?? const [])
              .where((member) => !_pendingOnly || !member.isActive)
              .toList();

          if (members.isEmpty) {
            return Center(
              child: Text(
                _pendingOnly
                    ? 'No newly registered members waiting for activation.'
                    : 'No members found.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              itemCount: members.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final member = members[index];
                return _MemberTile(
                  member: member,
                  onActivate: () => _confirmActivate(member),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member, required this.onActivate});

  final Member member;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      member.fullName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: member.isActive
                            ? Colors.green.shade50
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        member.isActive ? 'Active' : 'Pending',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: member.isActive
                              ? Colors.green.shade700
                              : Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  member.email,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                Text(
                  '${member.accessLevelLabel} · ${member.officeName}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          if (!member.isActive)
            FilledButton(
              onPressed: onActivate,
              style: FilledButton.styleFrom(backgroundColor: navyBlue),
              child: const Text('Activate'),
            ),
        ],
      ),
    );
  }
}
