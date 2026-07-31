import 'package:flutter/material.dart';

import 'models/member.dart';
import 'services/member_service.dart';
import 'theme.dart';

class MembersPage extends StatefulWidget {
  const MembersPage({super.key, required this.accessLevel});

  /// The signed-in caller's own access level (1 = Admin, 2 = Approver) --
  /// determines who they're allowed to edit and which Access Level options
  /// they're offered, mirroring the RLS scope in
  /// 023_approver_admin_edit_members.sql.
  final int accessLevel;

  @override
  State<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
  late Future<List<Member>> _membersFuture;
  bool _pendingOnly = false;

  bool get _isAdmin => widget.accessLevel == 1;

  bool _canEdit(Member member) => _isAdmin || member.accessLevel == 3;

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

  Future<void> _openEditDialog(Member member) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) =>
          _EditMemberDialog(member: member, isAdmin: _isAdmin),
    );
    if (saved == true) await _reload();
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
                  onEdit: _canEdit(member)
                      ? () => _openEditDialog(member)
                      : null,
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
  const _MemberTile({
    required this.member,
    required this.onActivate,
    this.onEdit,
  });

  final Member member;
  final VoidCallback onActivate;
  final VoidCallback? onEdit;

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
          if (onEdit != null)
            IconButton(
              onPressed: onEdit,
              tooltip: 'Edit member',
              icon: const Icon(Icons.edit_outlined),
              color: navyBlue,
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

class _EditMemberDialog extends StatefulWidget {
  const _EditMemberDialog({required this.member, required this.isAdmin});

  final Member member;

  /// Whether the signed-in caller is an Admin -- determines whether the
  /// Access Level dropdown offers Admin as an option, matching the RLS
  /// boundary in 023_approver_admin_edit_members.sql (an Approver can never
  /// grant Admin).
  final bool isAdmin;

  @override
  State<_EditMemberDialog> createState() => _EditMemberDialogState();
}

class _EditMemberDialogState extends State<_EditMemberDialog> {
  late final _positionController = TextEditingController(
    text: widget.member.position,
  );
  late int _accessLevel = widget.member.accessLevel;
  late bool _isActive = widget.member.isActive;
  bool _isSaving = false;

  @override
  void dispose() {
    _positionController.dispose();
    super.dispose();
  }

  List<int> get _accessLevelOptions => widget.isAdmin ? [1, 2, 3] : [2, 3];

  String _accessLevelLabel(int level) => switch (level) {
    1 => 'Admin',
    2 => 'Approver',
    _ => 'Employee',
  };

  Future<void> _save() async {
    final position = _positionController.text.trim();
    if (position.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a position')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      await MemberService.updateMember(
        userId: widget.member.id,
        position: position,
        accessLevel: _accessLevel,
        isActive: _isActive,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save: $error')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Edit Member',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: navyBlue,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close_rounded),
                    color: Colors.grey.shade500,
                    splashRadius: 20,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${widget.member.fullName} — ${widget.member.email}',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _positionController,
                decoration: const InputDecoration(labelText: 'Position'),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                initialValue: _accessLevel,
                decoration: const InputDecoration(labelText: 'Access Level'),
                items: [
                  for (final level in _accessLevelOptions)
                    DropdownMenuItem(
                      value: level,
                      child: Text(_accessLevelLabel(level)),
                    ),
                ],
                onChanged: (level) {
                  if (level != null) setState(() => _accessLevel = level);
                },
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F2F5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SwitchListTile(
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                  title: const Text(
                    'Active',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: navyBlue,
                    ),
                  ),
                  activeTrackColor: navyBlue,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _isSaving ? null : _save,
                    style: FilledButton.styleFrom(backgroundColor: navyBlue),
                    child: Text(_isSaving ? 'Saving…' : 'Save'),
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
