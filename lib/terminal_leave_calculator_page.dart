import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/leave_balance.dart';
import 'services/leave_service.dart';
import 'theme.dart';

/// Official DBM/CSC constant factor for terminal leave benefit computation:
/// TLB = highest monthly salary x CF x total accumulated leave credits
/// (unused VL + SL days, per the Service Record and CSC Form 6 Leave Card).
const _constantFactor = 0.0481927;

class TerminalLeaveCalculatorPage extends StatefulWidget {
  const TerminalLeaveCalculatorPage({super.key});

  @override
  State<TerminalLeaveCalculatorPage> createState() =>
      _TerminalLeaveCalculatorPageState();
}

class _TerminalLeaveCalculatorPageState
    extends State<TerminalLeaveCalculatorPage> {
  final _salaryController = TextEditingController();
  final _vlController = TextEditingController();
  final _slController = TextEditingController();

  double? _resultAmount;
  double? _resultCredits;

  @override
  void initState() {
    super.initState();
    _prefillFromBalances();
  }

  @override
  void dispose() {
    _salaryController.dispose();
    _vlController.dispose();
    _slController.dispose();
    super.dispose();
  }

  Future<void> _prefillFromBalances() async {
    final balances = await LeaveService.fetchCurrentEmployeeBalances();
    if (!mounted || balances.isEmpty) return;

    LeaveBalance? findByName(String name) {
      for (final balance in balances) {
        if (balance.leaveTypeName == name) return balance;
      }
      return null;
    }

    final vl = findByName('Vacation Leave');
    final sl = findByName('Sick Leave');
    setState(() {
      if (vl != null) _vlController.text = _formatDays(vl.availableBalance);
      if (sl != null) _slController.text = _formatDays(sl.availableBalance);
    });
  }

  String _formatDays(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);

  void _compute() {
    final salary = double.tryParse(_salaryController.text.trim());
    if (salary == null || salary <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter your highest monthly salary received'),
        ),
      );
      return;
    }

    final vl = double.tryParse(_vlController.text.trim()) ?? 0;
    final sl = double.tryParse(_slController.text.trim()) ?? 0;
    final credits = vl + sl;

    setState(() {
      _resultCredits = credits;
      _resultAmount = salary * _constantFactor * credits;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Header(),
          const SizedBox(height: 20),
          _InputCard(
            salaryController: _salaryController,
            vlController: _vlController,
            slController: _slController,
            onCompute: _compute,
          ),
          if (_resultAmount != null) ...[
            const SizedBox(height: 16),
            _ResultCard(credits: _resultCredits!, amount: _resultAmount!),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      decoration: BoxDecoration(
        color: navyBlue,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: navyBlue.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: taupe,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'TERMINAL LEAVE BENEFIT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: navyBlue,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.calculate_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Terminal Leave Benefit Calculator',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Estimate the money value of your accumulated leave credits '
            'upon retirement, resignation, or separation from government '
            'service.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputCard extends StatelessWidget {
  const _InputCard({
    required this.salaryController,
    required this.vlController,
    required this.slController,
    required this.onCompute,
  });

  final TextEditingController salaryController;
  final TextEditingController vlController;
  final TextEditingController slController;
  final VoidCallback onCompute;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: navyBlue.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FieldLabel('Highest Monthly Salary Received'),
          const SizedBox(height: 8),
          TextField(
            controller: salaryController,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            decoration: const InputDecoration(
              prefixIcon: Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  '₱',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: navyBlue,
                  ),
                ),
              ),
              prefixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Use the highest basic monthly salary you received during your '
            'entire government service — not necessarily your last salary.',
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Vacation Leave Credits'),
                    const SizedBox(height: 8),
                    _DaysField(controller: vlController),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Sick Leave Credits'),
                    const SizedBox(height: 8),
                    _DaysField(controller: slController),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Total unused/accumulated VL and SL as of your last day of '
            'service, per your Service Record and CSC Form 6 (Leave Card). '
            'Pre-filled from your current available balance — adjust if '
            'estimating for a future date.',
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onCompute,
              style: FilledButton.styleFrom(
                backgroundColor: taupe,
                foregroundColor: navyBlue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Compute Terminal Leave Benefit',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DaysField extends StatelessWidget {
  const _DaysField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      decoration: InputDecoration(
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Center(
            widthFactor: 1,
            child: Text(
              'days',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: navyBlue,
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.credits, required this.amount});

  final double credits;
  final double amount;

  String _formatCurrency(double value) {
    final fixed = value.toStringAsFixed(2);
    final parts = fixed.split('.');
    final whole = parts[0];
    final buffer = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      final fromEnd = whole.length - i;
      buffer.write(whole[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buffer.write(',');
    }
    return '${buffer.toString()}.${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: navyBlue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: navyBlue.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.savings_rounded,
                size: 18,
                color: navyBlue,
              ),
              const SizedBox(width: 8),
              const Text(
                'Estimated Terminal Leave Benefit',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: navyBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '₱ ${_formatCurrency(amount)}',
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: navyBlue,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Total leave credits: ${credits.toStringAsFixed(2)} day(s)',
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
          ),
          Text(
            'Formula: salary × 0.0481927 × leave credits',
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 10),
          Text(
            'This is an estimate only, based on the standard DBM/CSC '
            'constant factor. Your actual terminal leave benefit is '
            'computed and released by your HR/Accounting office.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
