import 'package:chronyx/core/errors/error_message_mapper.dart';
import 'package:chronyx/core/routing/app_routes.dart';
import 'package:chronyx/core/utils/responsive.dart';
import 'package:chronyx/core/widgets/page_header.dart';
import 'package:chronyx/core/widgets/state_view.dart';
import 'package:chronyx/features/goals/presentation/providers/goals_providers.dart';
import 'package:chronyx/features/goals/presentation/widgets/goal_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const _kPad = 20.0;

class GoalsPage extends ConsumerWidget {
  const GoalsPage({super.key});

  Future<void> _createGoal(BuildContext context, WidgetRef ref) async {
    await context.push(AppRoutes.goalsCreate);
    ref.read(goalsProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(goalsProvider);

    return Scaffold(
      // The floating bottom nav is 64 tall with a 12 bottom margin and already
      // sits inside the shell's SafeArea. The page Scaffold's FAB already clears
      // the system inset + its own 16 margin, so we add ~60 to rest just above
      // the nav pill without floating too high.
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 72),
        child: FloatingActionButton.extended(
          onPressed: state.isLoading ? null : () => _createGoal(context, ref),
          icon: const Icon(Icons.add_rounded),
          label: const Text('New goal'),
        ),
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          bottom: false,
          child: ResponsiveCenter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(_kPad, 12, _kPad, 16),
                  child: PageHeader(title: 'Goals'),
                ),
                Expanded(
                  child: state.when(
                    data: (items) {
                      if (items.isEmpty) {
                        return StateView.empty(
                          icon: Icons.flag_outlined,
                          title: 'No goals yet',
                          message:
                              'Create a goal to build a streak and stay accountable.',
                          actionLabel: 'Create goal',
                          onAction: () => _createGoal(context, ref),
                        );
                      }
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: ListView.separated(
                          key: ValueKey('goals_list_${items.length}'),
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(
                            _kPad,
                            0,
                            _kPad,
                            140,
                          ),
                          itemCount: items.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final g = items[index];
                            return GoalCard(
                              progress: g,
                              onTap: () => context.push('/goals/${g.goal.id}'),
                            );
                          },
                        ),
                      );
                    },
                    error: (err, _) => StateView.error(
                      message: ErrorMessageMapper.fromError(err),
                      onRetry: () => ref.read(goalsProvider.notifier).refresh(),
                    ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
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
