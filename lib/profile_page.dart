import 'package:flutter/material.dart';

import 'models/user_profile.dart';
import 'services/profile_service.dart';
import 'theme.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Future<UserProfile?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = ProfileService.fetchCurrentProfile();
  }

  Future<void> _reload() {
    final future = ProfileService.fetchCurrentProfile();
    setState(() {
      _profileFuture = future;
    });
    return future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 40,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Could not load your profile.\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(onPressed: _reload, child: const Text('Retry')),
                ],
              ),
            ),
          );
        }

        final profile = snapshot.data;
        if (profile == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_off_outlined,
                    size: 40,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No profile found for your account.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ProfileHeaderCard(profile: profile),
              const SizedBox(height: 16),
              _ProfileDetailsCard(
                title: 'Account',
                rows: [
                  _DetailRow('Email', profile.email),
                  _DetailRow('Office', profile.officeName),
                  _DetailRow('Position', profile.position),
                  _DetailRow('Access Level', profile.accessLevelLabel),
                  _DetailRow(
                    'Status',
                    profile.isActive ? 'Active' : 'Inactive',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (profile.isLinkedToEmployeeRecord)
                _EmploymentEditCard(profile: profile, onSaved: _reload)
              else
                const _ProfileDetailsCard(
                  title: 'Employment',
                  rows: null,
                  emptyMessage:
                      'No employee record is linked to your account yet.\n'
                      'Contact your administrator to have it set up.',
                ),
            ],
          ),
        );
      },
    );
  }
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

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: navyBlue.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: taupe,
            child: Text(
              profile.initials,
              style: const TextStyle(
                color: navyBlue,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.fullName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: navyBlue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.position,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _tint(navyBlue, 0.9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    profile.accessLevelLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: navyBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _tint(Color base, double amount) =>
      Color.lerp(base, Colors.white, amount)!;
}

class _DetailRow {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;
}

class _ProfileDetailsCard extends StatelessWidget {
  const _ProfileDetailsCard({
    required this.title,
    required this.rows,
    this.emptyMessage,
  });

  final String title;
  final List<_DetailRow>? rows;
  final String? emptyMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: navyBlue.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: navyBlue,
            ),
          ),
          const SizedBox(height: 12),
          if (rows == null)
            Text(
              emptyMessage ?? '',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            )
          else
            for (final row in rows!) _DetailRowTile(row: row),
        ],
      ),
    );
  }
}

class _DetailRowTile extends StatelessWidget {
  const _DetailRowTile({required this.row});

  final _DetailRow row;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              row.label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ),
          Expanded(
            child: Text(
              row.value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: navyBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmploymentEditCard extends StatefulWidget {
  const _EmploymentEditCard({required this.profile, required this.onSaved});

  final UserProfile profile;
  final Future<void> Function() onSaved;

  @override
  State<_EmploymentEditCard> createState() => _EmploymentEditCardState();
}

class _EmploymentEditCardState extends State<_EmploymentEditCard> {
  late final TextEditingController _employeeNoController;
  late final TextEditingController _employmentStatusController;
  late final TextEditingController _civilStatusController;
  late final TextEditingController _gsisNoController;
  late final TextEditingController _tinNoController;
  DateTime? _dateHired;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _employeeNoController = TextEditingController(
      text: profile.employeeNo ?? '',
    );
    _employmentStatusController = TextEditingController(
      text: profile.employmentStatus ?? '',
    );
    _civilStatusController = TextEditingController(
      text: profile.civilStatus ?? '',
    );
    _gsisNoController = TextEditingController(text: profile.gsisNo ?? '');
    _tinNoController = TextEditingController(text: profile.tinNo ?? '');
    _dateHired = profile.dateHired;
  }

  @override
  void dispose() {
    _employeeNoController.dispose();
    _employmentStatusController.dispose();
    _civilStatusController.dispose();
    _gsisNoController.dispose();
    _tinNoController.dispose();
    super.dispose();
  }

  Future<void> _pickDateHired() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateHired ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dateHired = picked);
  }

  String? _blankToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _save() async {
    final employeeId = widget.profile.employeeId;
    if (employeeId == null) return;

    setState(() => _isSaving = true);
    try {
      await ProfileService.updateEmployment(
        employeeId: employeeId,
        employeeNo: _blankToNull(_employeeNoController.text),
        employmentStatus: _blankToNull(_employmentStatusController.text),
        civilStatus: _blankToNull(_civilStatusController.text),
        gsisNo: _blankToNull(_gsisNoController.text),
        tinNo: _blankToNull(_tinNoController.text),
        dateHired: _dateHired,
      );
      await widget.onSaved();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Employment details saved')));
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: navyBlue.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Employment',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: navyBlue,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _employeeNoController,
            decoration: const InputDecoration(
              labelText: 'Employee No.',
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _employmentStatusController,
            decoration: const InputDecoration(
              labelText: 'Employment Status',
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _civilStatusController,
            decoration: const InputDecoration(
              labelText: 'Civil Status',
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _gsisNoController,
            decoration: const InputDecoration(
              labelText: 'GSIS No.',
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tinNoController,
            decoration: const InputDecoration(
              labelText: 'TIN No.',
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _isSaving ? null : _pickDateHired,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Date Hired',
                isDense: true,
              ),
              child: Text(
                _dateHired == null ? '—' : _formatDate(_dateHired!),
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _isSaving ? null : _save,
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
                  : const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}
