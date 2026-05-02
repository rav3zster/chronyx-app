import 'package:chronyx/core/constants/app_spacing.dart';
import 'package:chronyx/core/errors/error_message_mapper.dart';
import 'package:chronyx/features/goals/presentation/providers/goals_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CreateGoalPage extends ConsumerStatefulWidget {
  const CreateGoalPage({super.key});

  @override
  ConsumerState<CreateGoalPage> createState() => _CreateGoalPageState();
}

class _CreateGoalPageState extends ConsumerState<CreateGoalPage> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  DateTime? _start;
  DateTime? _end;
  final _target = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final picked = await showDatePicker(context: context, initialDate: now, firstDate: DateTime(now.year - 5), lastDate: DateTime(now.year + 5));
    if (picked != null) setState(() => _start = picked);
  }

  Future<void> _pickEnd() async {
    final now = DateTime.now();
    final picked = await showDatePicker(context: context, initialDate: _start ?? now, firstDate: DateTime(now.year - 5), lastDate: DateTime(now.year + 5));
    if (picked != null) setState(() => _end = picked);
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    final desc = _desc.text.trim();
    final target = int.tryParse(_target.text.trim()) ?? 0;
    if (title.isEmpty || _start == null || _end == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill required fields')));
      return;
    }

    try {
      await ref.read(goalsProvider.notifier).createGoal(
            title: title,
            description: desc,
            startDate: _start!,
            endDate: _end!,
            dailyTargetMinutes: target,
            isChallenge: false,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorMessageMapper.fromError(err))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Goal')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: ListView(
          children: <Widget>[
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: AppSpacing.sm),
            TextField(controller: _desc, decoration: const InputDecoration(labelText: 'Description')),
            const SizedBox(height: AppSpacing.sm),
            Row(children: <Widget>[
              Expanded(child: OutlinedButton(onPressed: _pickStart, child: Text(_start == null ? 'Select start' : _start!.toLocal().toString().split(' ').first))),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: OutlinedButton(onPressed: _pickEnd, child: Text(_end == null ? 'Select end' : _end!.toLocal().toString().split(' ').first))),
            ]),
            const SizedBox(height: AppSpacing.sm),
            TextField(controller: _target, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Daily target minutes')),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(onPressed: _submit, child: const Text('Create')),
          ],
        ),
      ),
    );
  }
}
