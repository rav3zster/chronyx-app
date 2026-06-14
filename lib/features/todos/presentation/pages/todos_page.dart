import 'dart:ui';
import 'package:chronyx/core/errors/error_message_mapper.dart';
import 'package:chronyx/core/utils/responsive.dart';
import 'package:chronyx/core/widgets/app_error_view.dart';
import 'package:chronyx/core/widgets/page_header.dart';
import 'package:chronyx/core/widgets/press_scale.dart';
import 'package:chronyx/features/project_planner/presentation/providers/project_planner_providers.dart';
import 'package:chronyx/features/goals/presentation/providers/goals_providers.dart';
import 'package:chronyx/features/todos/domain/entities/todo.dart';
import 'package:chronyx/features/todos/presentation/providers/todos_providers.dart';
import 'package:chronyx/features/todos/presentation/utils/todo_nli_parser.dart';
import 'package:chronyx/features/todos/presentation/utils/todo_checklist_parser.dart';
import 'package:chronyx/core/services/sound_service.dart';
import 'package:chronyx/core/services/haptic_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';


const _kRadius = 24.0;
const _kPad = 20.0;

class TodosPage extends ConsumerStatefulWidget {
  const TodosPage({super.key});

  @override
  ConsumerState<TodosPage> createState() => _TodosPageState();
}

class _TodosPageState extends ConsumerState<TodosPage> {
  int _tabIndex = 0; // 0 = List, 1 = Calendar
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _collapsedTodos = {};
  final Set<String> _collapsedSections = {};
  // ignore: unused_field
  bool _isSaving = false;
  bool _isDraggingTask = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      ref.read(todoSearchQueryProvider.notifier).state = _searchController.text;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showCreateDialog({String? parentId, DateTime? prefilledDate}) {
    ref.read(soundServiceProvider).buttonPress();
    ref.read(hapticServiceProvider).buttonPress();
    showDialog(
      context: context,
      builder: (context) => _CreateEditTodoDialog(
        parentId: parentId,
        prefilledDate: prefilledDate,
        ref: ref,
      ),
    );
  }

  void _showEditDialog(Todo todo) {
    ref.read(soundServiceProvider).buttonPress();
    ref.read(hapticServiceProvider).buttonPress();
    showDialog(
      context: context,
      builder: (context) => _CreateEditTodoDialog(
        todo: todo,
        ref: ref,
      ),
    );
  }

  void _showQuickAddBottomSheet() {
    ref.read(soundServiceProvider).buttonPress();
    ref.read(hapticServiceProvider).buttonPress();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _QuickAddBottomSheet(ref: ref),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(todoSelectedViewProvider);
    final isCompact = context.isCompact;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _showQuickAddBottomSheet,
        tooltip: 'Quick Add Task',
        child: const Icon(Icons.bolt_rounded),
      ),
      body: SafeArea(
        bottom: false,
        child: ResponsiveCenter(
          maxWidth: Breakpoints.maxDoubleContent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header Row ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(_kPad, 12, _kPad, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                      onPressed: () => context.pop(),
                    ),
                    const Expanded(
                      child: PageHeader(title: 'To-Dos'),
                    ),
                    PressScale(
                      onTap: () => _showCreateDialog(
                        prefilledDate: _tabIndex == 1
                            ? ref.read(calendarSelectedDateProvider)
                            : null,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: scheme.primary.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_rounded, color: scheme.onPrimary, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              'ADD TASK',
                              style: TextStyle(
                                color: scheme.onPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Top Navigation View Switcher ──────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: _kPad),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _SubViewTab(
                          label: 'Lists & Folders',
                          icon: Icons.list_rounded,
                          isSelected: _tabIndex == 0,
                          onTap: () {
                            ref.read(soundServiceProvider).buttonPress();
                            ref.read(hapticServiceProvider).buttonPress();
                            setState(() => _tabIndex = 0);
                          },
                        ),
                      ),
                      Expanded(
                        child: _SubViewTab(
                          label: 'Calendar',
                          icon: Icons.date_range_rounded,
                          isSelected: _tabIndex == 1,
                          onTap: () {
                            ref.read(soundServiceProvider).buttonPress();
                            ref.read(hapticServiceProvider).buttonPress();
                            setState(() {
                              _tabIndex = 1;
                              // Default view to Calendar in Providers when clicking Calendar Tab
                              ref.read(todoSelectedViewProvider.notifier).state = TodoViewType.calendar;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // ── Main Content Area ──────────────────────────────────────────
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _tabIndex == 0 
                      ? _buildDashboardView(scheme, isCompact) 
                      : _buildCalendarView(scheme),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Sub-view 1: Lists & Folders View ────────────────────────────────────────
  Widget _buildDashboardView(ColorScheme scheme, bool isCompact) {
    final textTheme = Theme.of(context).textTheme;
    final allTodosAsync = ref.watch(todosProvider);

    return Column(
      key: const ValueKey('dashboard_view'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Grid of Folders (Inbox, Today, Important, Upcoming, Completed, All)
        allTodosAsync.when(
          data: (todos) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: _kPad),
              child: _buildFoldersGrid(todos, scheme),
            );
          },
          loading: () => const SizedBox(height: 110),
          error: (_, __) => const SizedBox(),
        ),
        const SizedBox(height: 16),

        // 2. Search Field & Active Filter Banner
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _kPad),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Icon(Icons.search, size: 18),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: textTheme.bodyMedium,
                          decoration: const InputDecoration(
                            hintText: 'Search tasks...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.only(bottom: 6),
                          ),
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () => _searchController.clear(),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _showFiltersDialog,
                child: Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
                  ),
                  child: Icon(Icons.filter_alt_outlined, color: scheme.onSurfaceVariant, size: 20),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Active Folder Heading
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _kPad),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                ref.watch(todoSelectedViewProvider).label.toUpperCase(),
                style: textTheme.labelMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      ref.watch(todoGroupBySectionProvider) 
                          ? Icons.grid_view_rounded 
                          : Icons.view_headline_rounded,
                      size: 20,
                      color: ref.watch(todoGroupBySectionProvider) ? scheme.primary : scheme.onSurfaceVariant,
                    ),
                    tooltip: 'Group by Section',
                    onPressed: () {
                      ref.read(soundServiceProvider).buttonPress();
                      ref.read(hapticServiceProvider).buttonPress();
                      ref.read(todoGroupBySectionProvider.notifier).update((val) => !val);
                    },
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    icon: Icon(
                      ref.watch(todoSelectionModeProvider) 
                          ? Icons.close_rounded 
                          : Icons.playlist_add_check_rounded,
                      size: 18,
                    ),
                    label: Text(ref.watch(todoSelectionModeProvider) ? 'Cancel' : 'Select'),
                    onPressed: () {
                      ref.read(soundServiceProvider).buttonPress();
                      ref.read(hapticServiceProvider).buttonPress();
                      final isMode = ref.read(todoSelectionModeProvider);
                      ref.read(todoSelectionModeProvider.notifier).state = !isMode;
                      ref.read(todoSelectedIdsProvider.notifier).state = const {};
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 3. To-Do Hierarchy List
        Expanded(
          child: Stack(
            children: [
              ref.watch(todosProvider).when(
                data: (_) {
                  final flatFiltered = ref.watch(filteredTodosProvider);
                  final treeList = ref.watch(todoTreeProvider(flatFiltered));

                  if (treeList.isEmpty) {
                    return const Center(child: _NoTodosView());
                  }

                  final groupBySection = ref.watch(todoGroupBySectionProvider);
                  if (groupBySection) {
                    final Map<String, List<Todo>> grouped = {};
                    for (final item in treeList) {
                      final cat = item.category?.trim() ?? 'No Section';
                      grouped.putIfAbsent(cat, () => []).add(item);
                    }
                    
                    final sortedCategories = grouped.keys.toList()..sort((a, b) {
                      if (a == 'No Section') return 1;
                      if (b == 'No Section') return -1;
                      return a.compareTo(b);
                    });

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(_kPad, 0, _kPad, 100),
                      physics: const BouncingScrollPhysics(),
                      itemCount: sortedCategories.length,
                      itemBuilder: (context, catIdx) {
                        final cat = sortedCategories[catIdx];
                        final catTodos = grouped[cat] ?? [];
                        final isCollapsed = _collapsedSections.contains(cat);

                        return DragTarget<Todo>(
                          onWillAcceptWithDetails: (details) => details.data.category != cat && !(cat == 'No Section' && details.data.category == null),
                          onAcceptWithDetails: (details) async {
                            ref.read(soundServiceProvider).buttonPress();
                            ref.read(hapticServiceProvider).buttonPress();
                            final cleanCategory = cat == 'No Section' ? '' : cat;
                            await ref.read(todosProvider.notifier).updateTodo(
                              id: details.data.id,
                              category: cleanCategory,
                            );
                          },
                          builder: (context, candidateData, rejectedData) {
                            final isOver = candidateData.isNotEmpty;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: isOver ? Border.all(color: scheme.primary, width: 2) : null,
                                color: isOver ? scheme.primary.withValues(alpha: 0.05) : Colors.transparent,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  InkWell(
                                    onTap: () {
                                      ref.read(soundServiceProvider).buttonPress();
                                      ref.read(hapticServiceProvider).buttonPress();
                                      setState(() {
                                        if (isCollapsed) {
                                          _collapsedSections.remove(cat);
                                        } else {
                                          _collapsedSections.add(cat);
                                        }
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isCollapsed 
                                                ? Icons.keyboard_arrow_right_rounded 
                                                : Icons.keyboard_arrow_down_rounded,
                                            size: 20,
                                            color: scheme.onSurfaceVariant,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            cat.toUpperCase(),
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 12,
                                              letterSpacing: 1.0,
                                              color: scheme.primary,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: scheme.primary.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '${catTodos.length}',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: scheme.primary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (!isCollapsed) ...[
                                    const SizedBox(height: 8),
                                    ...catTodos.map((todo) => _buildRecursiveTodo(todo, 0)),
                                  ],
                                ],
                              ),
                            );
                          },
                        );
                      },
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(_kPad, 0, _kPad, 100),
                    physics: const BouncingScrollPhysics(),
                    itemCount: treeList.length,
                    itemBuilder: (context, index) {
                      return _buildRecursiveTodo(treeList[index], 0);
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => AppErrorView(
                  message: ErrorMessageMapper.fromError(err),
                  onRetry: () => ref.read(todosProvider.notifier).refreshTodos(),
                ),
              ),
              
              // Move to root level drop target overlay
              if (_isDraggingTask)
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: ref.watch(todoSelectionModeProvider) ? 96 : 32,
                  child: DragTarget<Todo>(
                    onWillAcceptWithDetails: (details) => details.data.parentId != null,
                    onAcceptWithDetails: (details) async {
                      ref.read(soundServiceProvider).buttonPress();
                      ref.read(hapticServiceProvider).buttonPress();
                      await ref.read(todosProvider.notifier).updateTodo(
                        id: details.data.id,
                        clearParentId: true,
                      );
                    },
                    builder: (context, candidateData, rejectedData) {
                      final isOver = candidateData.isNotEmpty;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 54,
                        decoration: BoxDecoration(
                          color: isOver 
                              ? Colors.green.withValues(alpha: 0.2) 
                              : scheme.surfaceContainerHighest.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isOver ? Colors.green : scheme.outlineVariant,
                            width: 2.0,
                          ),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
                          ],
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.unarchive_rounded,
                                color: isOver ? Colors.green : scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Drag here to move to Root Level',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isOver ? Colors.green : scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

              // Floating batch actions bar
              if (ref.watch(todoSelectionModeProvider))
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 24,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainer.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _BatchActionButton(
                              icon: Icons.check_circle_outline_rounded,
                              label: 'Complete',
                              onTap: _batchComplete,
                            ),
                            _BatchActionButton(
                              icon: Icons.priority_high_rounded,
                              label: 'Priority',
                              onTap: _batchChangePriority,
                            ),
                            _BatchActionButton(
                              icon: Icons.category_outlined,
                              label: 'Category',
                              onTap: _batchMoveCategory,
                            ),
                            _BatchActionButton(
                              icon: Icons.folder_open_rounded,
                              label: 'Project',
                              onTap: _batchMoveProject,
                            ),
                            _BatchActionButton(
                              icon: Icons.delete_outline_rounded,
                              label: 'Delete',
                              color: scheme.error,
                              onTap: _batchDelete,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFoldersGrid(List<Todo> todos, ColorScheme scheme) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    // Calculate category counts
    final inboxCount = todos.where((t) => t.parentId == null && t.status != TodoStatus.completed && t.status != TodoStatus.archived).length;
    final todayCount = todos.where((t) => t.dueDate != null && t.dueDate!.isBefore(todayEnd) && t.status != TodoStatus.completed && t.status != TodoStatus.archived).length;
    final importantCount = todos.where((t) => (t.priority == TodoPriority.high || t.priority == TodoPriority.critical) && t.status != TodoStatus.completed && t.status != TodoStatus.archived).length;
    final upcomingCount = todos.where((t) => t.dueDate != null && t.dueDate!.isAfter(todayStart) && t.status != TodoStatus.completed && t.status != TodoStatus.archived).length;
    final completedCount = todos.where((t) => t.status == TodoStatus.completed).length;
    final overdueCount = todos.where((t) => t.dueDate != null && t.dueDate!.isBefore(todayStart) && t.status != TodoStatus.completed && t.status != TodoStatus.archived).length;
    final scheduledCount = todos.where((t) => t.dueDate != null && t.status != TodoStatus.completed && t.status != TodoStatus.archived).length;
    final noDateCount = todos.where((t) => t.dueDate == null && t.status != TodoStatus.completed && t.status != TodoStatus.archived).length;
    final recurringCount = todos.where((t) => t.recurrence != null && t.status != TodoStatus.completed && t.status != TodoStatus.archived).length;
    final allCount = todos.length;

    final viewType = ref.watch(todoSelectedViewProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth > 800 ? 5 : (constraints.maxWidth > 500 ? 4 : 2);
        return GridView.count(
          crossAxisCount: crossCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.6,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: [
            _FolderCard(
              viewType: TodoViewType.inbox,
              count: inboxCount,
              isSelected: viewType == TodoViewType.inbox,
              color: Colors.blueAccent,
              onTap: () => _selectFolder(TodoViewType.inbox),
            ),
            _FolderCard(
              viewType: TodoViewType.today,
              count: todayCount,
              isSelected: viewType == TodoViewType.today,
              color: Colors.amber,
              onTap: () => _selectFolder(TodoViewType.today),
            ),
            _FolderCard(
              viewType: TodoViewType.important,
              count: importantCount,
              isSelected: viewType == TodoViewType.important,
              color: Colors.redAccent,
              onTap: () => _selectFolder(TodoViewType.important),
            ),
            _FolderCard(
              viewType: TodoViewType.upcoming,
              count: upcomingCount,
              isSelected: viewType == TodoViewType.upcoming,
              color: Colors.deepPurpleAccent,
              onTap: () => _selectFolder(TodoViewType.upcoming),
            ),
            _FolderCard(
              viewType: TodoViewType.completed,
              count: completedCount,
              isSelected: viewType == TodoViewType.completed,
              color: Colors.green,
              onTap: () => _selectFolder(TodoViewType.completed),
            ),
            _FolderCard(
              viewType: TodoViewType.overdue,
              count: overdueCount,
              isSelected: viewType == TodoViewType.overdue,
              color: Colors.deepOrange,
              onTap: () => _selectFolder(TodoViewType.overdue),
            ),
            _FolderCard(
              viewType: TodoViewType.scheduled,
              count: scheduledCount,
              isSelected: viewType == TodoViewType.scheduled,
              color: Colors.teal,
              onTap: () => _selectFolder(TodoViewType.scheduled),
            ),
            _FolderCard(
              viewType: TodoViewType.noDate,
              count: noDateCount,
              isSelected: viewType == TodoViewType.noDate,
              color: Colors.grey,
              onTap: () => _selectFolder(TodoViewType.noDate),
            ),
            _FolderCard(
              viewType: TodoViewType.recurring,
              count: recurringCount,
              isSelected: viewType == TodoViewType.recurring,
              color: Colors.pinkAccent,
              onTap: () => _selectFolder(TodoViewType.recurring),
            ),
            _FolderCard(
              viewType: TodoViewType.all,
              count: allCount,
              isSelected: viewType == TodoViewType.all,
              color: Colors.blueGrey,
              onTap: () => _selectFolder(TodoViewType.all),
            ),
          ],
        );
      },
    );
  }

  void _selectFolder(TodoViewType folder) {
    ref.read(soundServiceProvider).buttonPress();
    ref.read(hapticServiceProvider).buttonPress();
    ref.read(todoSelectedViewProvider.notifier).state = folder;
  }

  void _showFiltersDialog() {
    ref.read(soundServiceProvider).buttonPress();
    ref.read(hapticServiceProvider).buttonPress();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(_kRadius)),
      ),
      builder: (context) => _FilterBottomSheet(ref: ref),
    );
  }

  // ── Recursive Subtask card builder ─────────────────────────────────────────
  Widget _buildRecursiveTodo(Todo todo, int level) {
    final hasChildren = todo.subtasks.isNotEmpty;
    final isCollapsed = _collapsedTodos.contains(todo.id);

    final selectionMode = ref.watch(todoSelectionModeProvider);
    final isSelected = ref.watch(todoSelectedIdsProvider).contains(todo.id);

    final allTodos = ref.read(todosProvider).valueOrNull ?? [];
    final isBlocked = todo.blockedByIds.isNotEmpty && allTodos.any((t) => todo.blockedByIds.contains(t.id) && t.status != TodoStatus.completed);

    final card = _TodoCard(
      todo: todo,
      selectionMode: selectionMode,
      isSelected: isSelected,
      isBlocked: isBlocked,
      onSelectedToggle: () {
        ref.read(soundServiceProvider).buttonPress();
        ref.read(hapticServiceProvider).buttonPress();
        final selected = Set<String>.from(ref.read(todoSelectedIdsProvider));
        if (selected.contains(todo.id)) {
          selected.remove(todo.id);
        } else {
          selected.add(todo.id);
        }
        ref.read(todoSelectedIdsProvider.notifier).state = selected;
      },
      onToggleStatus: () => ref.read(todosProvider.notifier).toggleTodoStatus(todo.id),
      onEdit: () => _showEditDialog(todo),
      onDelete: () => _deleteTodo(todo.id),
      onAddSubtask: () => _showCreateDialog(parentId: todo.id),
      hasChildren: hasChildren,
      isCollapsed: isCollapsed,
      onToggleCollapse: () {
        ref.read(soundServiceProvider).buttonPress();
        ref.read(hapticServiceProvider).buttonPress();
        setState(() {
          if (isCollapsed) {
            _collapsedTodos.remove(todo.id);
          } else {
            _collapsedTodos.add(todo.id);
          }
        });
      },
    );

    // If selection mode, return without drag support
    if (selectionMode) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.only(left: level * 16.0),
            child: card,
          ),
          const SizedBox(height: 8),
          if (hasChildren && !isCollapsed)
            ...todo.subtasks.map((child) => _buildRecursiveTodo(child, level + 1)),
        ],
      );
    }

    final draggableCard = LongPressDraggable<Todo>(
      data: todo,
      onDragStarted: () => setState(() => _isDraggingTask = true),
      onDragEnd: (_) => setState(() => _isDraggingTask = false),
      onDraggableCanceled: (_, __) => setState(() => _isDraggingTask = false),
      feedback: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 40),
          child: Opacity(opacity: 0.9, child: card),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: card),
      child: card,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.only(left: level * 16.0),
          child: TodoDragTargetWrapper(
            todo: todo,
            onReorder: _handleReorder,
            onMakeSubtask: _handleMakeSubtask,
            child: draggableCard,
          ),
        ),
        const SizedBox(height: 8),
        if (hasChildren && !isCollapsed)
          ...todo.subtasks.map((child) => _buildRecursiveTodo(child, level + 1)),
      ],
    );
  }

  void _deleteTodo(String id) async {
    ref.read(soundServiceProvider).buttonPress();
    ref.read(hapticServiceProvider).buttonPress();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete Task'),
        content: const Text('Are you sure you want to delete this To-Do? If it has subtasks, they will be deleted as well.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(todosProvider.notifier).deleteTodo(id: id);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: ${ErrorMessageMapper.fromError(e)}')),
        );
      }
    }
  }

  Future<void> _handleReorder(Todo dragged, Todo target, bool before) async {
    ref.read(soundServiceProvider).buttonPress();
    ref.read(hapticServiceProvider).buttonPress();

    if (dragged.parentId != target.parentId) {
      await ref.read(todosProvider.notifier).updateTodo(
        id: dragged.id,
        parentId: target.parentId,
      );
    }

    final currentOrder = ref.read(todoOrderProvider);
    final newOrder = List<String>.from(currentOrder);
    
    final allTodos = ref.read(todosProvider).valueOrNull ?? [];
    for (final t in allTodos) {
      if (!newOrder.contains(t.id)) {
        newOrder.add(t.id);
      }
    }

    newOrder.remove(dragged.id);
    final targetIndex = newOrder.indexOf(target.id);
    if (targetIndex != -1) {
      final insertIndex = before ? targetIndex : targetIndex + 1;
      newOrder.insert(insertIndex, dragged.id);
    } else {
      newOrder.add(dragged.id);
    }

    await ref.read(todoOrderProvider.notifier).updateOrder(newOrder);
  }

  Future<void> _handleMakeSubtask(Todo dragged, Todo newParent) async {
    ref.read(soundServiceProvider).buttonPress();
    ref.read(hapticServiceProvider).buttonPress();

    await ref.read(todosProvider.notifier).updateTodo(
      id: dragged.id,
      parentId: newParent.id,
    );
  }

  Future<void> _batchComplete() async {
    final ids = ref.read(todoSelectedIdsProvider);
    if (ids.isEmpty) return;

    ref.read(soundServiceProvider).buttonPress();
    ref.read(hapticServiceProvider).buttonPress();
    setState(() => _isSaving = true);
    try {
      final todos = ref.read(todosProvider).valueOrNull ?? [];
      final futures = ids.map((id) {
        final todo = todos.firstWhere((t) => t.id == id);
        if (todo.status != TodoStatus.completed) {
          return ref.read(todosProvider.notifier).toggleTodoStatus(id);
        }
        return Future.value();
      });
      await Future.wait(futures);
      ref.read(todoSelectionModeProvider.notifier).state = false;
      ref.read(todoSelectedIdsProvider.notifier).state = const {};
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to complete tasks: ${ErrorMessageMapper.fromError(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _batchDelete() async {
    final ids = ref.read(todoSelectedIdsProvider);
    if (ids.isEmpty) return;

    ref.read(soundServiceProvider).buttonPress();
    ref.read(hapticServiceProvider).buttonPress();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Delete ${ids.length} Tasks'),
        content: const Text('Are you sure you want to delete all selected tasks and their subtasks?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);
    try {
      final futures = ids.map((id) => ref.read(todosProvider.notifier).deleteTodo(id: id));
      await Future.wait(futures);
      ref.read(todoSelectionModeProvider.notifier).state = false;
      ref.read(todoSelectedIdsProvider.notifier).state = const {};
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete tasks: ${ErrorMessageMapper.fromError(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _batchChangePriority() async {
    final ids = ref.read(todoSelectedIdsProvider);
    if (ids.isEmpty) return;

    ref.read(soundServiceProvider).buttonPress();
    ref.read(hapticServiceProvider).buttonPress();

    final priority = await showDialog<TodoPriority>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Set Priority'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        children: TodoPriority.values.map((prio) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, prio),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(prio.label, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          );
        }).toList(),
      ),
    );

    if (priority == null) return;

    setState(() => _isSaving = true);
    try {
      final futures = ids.map((id) => ref.read(todosProvider.notifier).updateTodo(
        id: id,
        priority: priority,
      ));
      await Future.wait(futures);
      ref.read(todoSelectionModeProvider.notifier).state = false;
      ref.read(todoSelectedIdsProvider.notifier).state = const {};
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update priorities: ${ErrorMessageMapper.fromError(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _batchMoveCategory() async {
    final ids = ref.read(todoSelectedIdsProvider);
    if (ids.isEmpty) return;

    ref.read(soundServiceProvider).buttonPress();
    ref.read(hapticServiceProvider).buttonPress();

    final categoryController = TextEditingController();
    final newCategory = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to Section (Category)'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: TextField(
          controller: categoryController,
          decoration: const InputDecoration(
            hintText: 'Work, Personal, Health, etc.',
            labelText: 'Section/Category Name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, categoryController.text.trim()),
            child: const Text('Move'),
          ),
        ],
      ),
    );

    if (newCategory == null) return;

    setState(() => _isSaving = true);
    try {
      final futures = ids.map((id) => ref.read(todosProvider.notifier).updateTodo(
        id: id,
        category: newCategory,
      ));
      await Future.wait(futures);
      ref.read(todoSelectionModeProvider.notifier).state = false;
      ref.read(todoSelectedIdsProvider.notifier).state = const {};
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to move categories: ${ErrorMessageMapper.fromError(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _batchMoveProject() async {
    final ids = ref.read(todoSelectedIdsProvider);
    if (ids.isEmpty) return;

    ref.read(soundServiceProvider).buttonPress();
    ref.read(hapticServiceProvider).buttonPress();

    final projects = ref.read(projectsProvider).valueOrNull ?? [];
    
    final newProjectId = await showDialog<String?>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Move to Project'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'clear'),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No Project', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ),
          ...projects.map((p) {
            return SimpleDialogOption(
              onPressed: () => Navigator.pop(context, p.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(p.title),
              ),
            );
          }),
        ],
      ),
    );

    if (newProjectId == null) return;

    setState(() => _isSaving = true);
    try {
      final futures = ids.map((id) => ref.read(todosProvider.notifier).updateTodo(
        id: id,
        projectId: newProjectId == 'clear' ? '' : newProjectId,
      ));
      await Future.wait(futures);
      ref.read(todoSelectionModeProvider.notifier).state = false;
      ref.read(todoSelectedIdsProvider.notifier).state = const {};
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to move projects: ${ErrorMessageMapper.fromError(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Sub-view 2: Calendar Visualization ─────────────────────────────────────
  Widget _buildCalendarView(ColorScheme scheme) {
    final textTheme = Theme.of(context).textTheme;
    final calendarType = ref.watch(calendarViewTypeProvider);

    return Column(
      key: const ValueKey('calendar_view'),
      children: [
        // Calendar header navigation
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _kPad),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatCalendarHeader(),
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_left_rounded, size: 30),
                    onPressed: () => _navigateCalendar(-1),
                  ),
                  TextButton(
                    onPressed: () {
                      ref.read(soundServiceProvider).buttonPress();
                      ref.read(hapticServiceProvider).buttonPress();
                      ref.read(calendarSelectedDateProvider.notifier).state = DateTime.now();
                    },
                    child: const Text('Today'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_right_rounded, size: 30),
                    onPressed: () => _navigateCalendar(1),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Sub view segmented selector (Day, Week, Month, Agenda)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _kPad, vertical: 8),
          child: Row(
            children: CalendarViewType.values.map((type) {
              final isSel = calendarType == type;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(type.name.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    selected: isSel,
                    onSelected: (val) {
                      if (val) {
                        ref.read(soundServiceProvider).buttonPress();
                        ref.read(hapticServiceProvider).buttonPress();
                        ref.read(calendarViewTypeProvider.notifier).state = type;
                      }
                    },
                    selectedColor: scheme.primary,
                    backgroundColor: Colors.transparent,
                    labelStyle: TextStyle(color: isSel ? scheme.onPrimary : scheme.onSurface),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),

        // Responsive Calendar Body
        Expanded(
          child: _buildCalendarBody(calendarType, scheme),
        ),
      ],
    );
  }

  String _formatCalendarHeader() {
    final date = ref.watch(calendarSelectedDateProvider);
    final view = ref.read(calendarViewTypeProvider);
    final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    if (view == CalendarViewType.day) {
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    }
    return '${months[date.month - 1]} ${date.year}';
  }

  void _navigateCalendar(int offset) {
    ref.read(soundServiceProvider).buttonPress();
    ref.read(hapticServiceProvider).buttonPress();
    final date = ref.read(calendarSelectedDateProvider);
    final view = ref.read(calendarViewTypeProvider);
    final notifier = ref.read(calendarSelectedDateProvider.notifier);

    if (view == CalendarViewType.day) {
      notifier.state = date.add(Duration(days: offset));
    } else if (view == CalendarViewType.week) {
      notifier.state = date.add(Duration(days: offset * 7));
    } else {
      // Month or Agenda: jump monthly
      notifier.state = DateTime(date.year, date.month + offset, 1);
    }
  }

  Widget _buildCalendarBody(CalendarViewType type, ColorScheme scheme) {
    switch (type) {
      case CalendarViewType.day:
        return _buildDayView(scheme);
      case CalendarViewType.week:
        return _buildWeekView(scheme);
      case CalendarViewType.month:
        return _buildMonthView(scheme);
      case CalendarViewType.agenda:
        return _buildAgendaView(scheme);
    }
  }

  // ── Month Calendar Grid ────────────────────────────────────────────────────
  Widget _buildMonthView(ColorScheme scheme) {
    final selectedMonth = ref.watch(calendarSelectedDateProvider);
    final allTodos = ref.watch(todosProvider).valueOrNull ?? [];

    final first = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final int daysSinceSunday = first.weekday % 7; 
    final startDate = first.subtract(Duration(days: daysSinceSunday));
    final gridDays = List.generate(42, (idx) => startDate.add(Duration(days: idx)));

    final weekdayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return Column(
      children: [
        // Weekday labels
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _kPad),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weekdayLabels.map((lbl) => Text(lbl, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))).toList(),
          ),
        ),
        const SizedBox(height: 8),

        // Month Days Grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: _kPad),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: 42,
            itemBuilder: (context, index) {
              final dayDate = gridDays[index];
              final isCurrentMonth = dayDate.month == selectedMonth.month;
              final isSelected = DateUtils.isSameDay(dayDate, ref.watch(calendarSelectedDateProvider));
              
              // Get scheduled tasks for this day
              final dayTodos = allTodos.where((t) => t.dueDate != null && DateUtils.isSameDay(t.dueDate, dayDate)).toList();

              // Get highest priority color
              Color? dotColor;
              if (dayTodos.isNotEmpty) {
                final hasCritical = dayTodos.any((t) => t.priority == TodoPriority.critical);
                final hasHigh = dayTodos.any((t) => t.priority == TodoPriority.high);
                final hasMedium = dayTodos.any((t) => t.priority == TodoPriority.medium);
                
                if (hasCritical) {
                  dotColor = Colors.redAccent;
                } else if (hasHigh) {
                  dotColor = Colors.orange;
                } else if (hasMedium) {
                  dotColor = Colors.amber;
                } else {
                  dotColor = Colors.blueGrey;
                }
              }

              return DragTarget<Todo>(
                onWillAcceptWithDetails: (details) => !DateUtils.isSameDay(details.data.dueDate, dayDate),
                onAcceptWithDetails: (details) async {
                  ref.read(soundServiceProvider).buttonPress();
                  ref.read(hapticServiceProvider).buttonPress();
                  await ref.read(todosProvider.notifier).updateTodo(
                    id: details.data.id,
                    dueDate: dayDate,
                    reminderTime: details.data.reminderTime != null
                        ? DateTime(dayDate.year, dayDate.month, dayDate.day, details.data.reminderTime!.hour, details.data.reminderTime!.minute)
                        : null,
                  );
                },
                builder: (context, candidateData, rejectedData) {
                  final isOver = candidateData.isNotEmpty;
                  return GestureDetector(
                    onTap: () {
                      ref.read(soundServiceProvider).buttonPress();
                      ref.read(hapticServiceProvider).buttonPress();
                      ref.read(calendarSelectedDateProvider.notifier).state = dayDate;
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: isOver
                            ? scheme.primary.withValues(alpha: 0.25)
                            : (isSelected 
                                ? scheme.primary 
                                : (isCurrentMonth ? scheme.surfaceContainerHighest.withValues(alpha: 0.3) : Colors.transparent)),
                        borderRadius: BorderRadius.circular(14),
                        border: isOver
                            ? Border.all(color: scheme.primary, width: 2.0)
                            : (DateUtils.isSameDay(dayDate, DateTime.now()) 
                                ? Border.all(color: scheme.primary, width: 1.5) 
                                : null),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${dayDate.day}',
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected 
                                  ? scheme.onPrimary 
                                  : (isCurrentMonth ? scheme.onSurface : scheme.onSurfaceVariant.withValues(alpha: 0.4)),
                            ),
                          ),
                          if (dotColor != null) ...[
                            const SizedBox(height: 2),
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: isSelected ? scheme.onPrimary : dotColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),

        // Scheduled items for selected day
        const SizedBox(height: 12),
        Container(
          height: 1,
          color: scheme.outlineVariant.withValues(alpha: 0.3),
        ),
        Expanded(
          child: _buildSelectedDateList(ref.watch(calendarSelectedDateProvider)),
        ),
      ],
    );
  }

  // ── Week Calendar Grid ─────────────────────────────────────────────────────
  Widget _buildWeekView(ColorScheme scheme) {
    final selectedDate = ref.watch(calendarSelectedDateProvider);
    final weekday = selectedDate.weekday % 7; // Sunday = 0
    final startOfWeek = selectedDate.subtract(Duration(days: weekday));
    
    final daysOfWeek = List.generate(7, (i) => startOfWeek.add(Duration(days: i)));
    final allTodos = ref.watch(todosProvider).valueOrNull ?? [];

    return PageView.builder(
      itemCount: 1, // static week for simple architecture
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: _kPad),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: List.generate(7, (i) {
              final dayDate = daysOfWeek[i];
              final isSelected = DateUtils.isSameDay(dayDate, selectedDate);
              final isToday = DateUtils.isSameDay(dayDate, DateTime.now());
              final dayTodos = allTodos.where((t) => t.dueDate != null && DateUtils.isSameDay(t.dueDate, dayDate)).toList();

              final dayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    children: [
                      // Header button
                      GestureDetector(
                        onTap: () {
                          ref.read(soundServiceProvider).buttonPress();
                          ref.read(hapticServiceProvider).buttonPress();
                          ref.read(calendarSelectedDateProvider.notifier).state = dayDate;
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? scheme.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: isToday ? Border.all(color: scheme.primary, width: 1.5) : null,
                          ),
                          child: Column(
                            children: [
                              Text(
                                dayLabels[i],
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? scheme.onPrimary : scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${dayDate.day}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: isSelected ? scheme.onPrimary : scheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      Expanded(
                        child: DragTarget<Todo>(
                          onWillAcceptWithDetails: (details) => !DateUtils.isSameDay(details.data.dueDate, dayDate),
                          onAcceptWithDetails: (details) async {
                            ref.read(soundServiceProvider).buttonPress();
                            ref.read(hapticServiceProvider).buttonPress();
                            await ref.read(todosProvider.notifier).updateTodo(
                              id: details.data.id,
                              dueDate: dayDate,
                              reminderTime: details.data.reminderTime != null
                                  ? DateTime(dayDate.year, dayDate.month, dayDate.day, details.data.reminderTime!.hour, details.data.reminderTime!.minute)
                                  : null,
                            );
                          },
                          builder: (context, candidateData, rejectedData) {
                            final isOver = candidateData.isNotEmpty;
                            return Container(
                              decoration: BoxDecoration(
                                color: isOver
                                    ? scheme.primary.withValues(alpha: 0.15)
                                    : scheme.surfaceContainerHighest.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(16),
                                border: isOver ? Border.all(color: scheme.primary, width: 2) : null,
                              ),
                              child: dayTodos.isEmpty
                                  ? Center(
                                      child: Icon(Icons.circle_outlined, size: 12, color: scheme.onSurfaceVariant.withValues(alpha: 0.2)),
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.all(4),
                                      itemCount: dayTodos.length,
                                      itemBuilder: (context, idx) {
                                        final item = dayTodos[idx];
                                        final card = Container(
                                          margin: const EdgeInsets.only(bottom: 4),
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: _colorForPriority(item.priority).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            item.title,
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: _colorForPriority(item.priority),
                                              decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );

                                        return LongPressDraggable<Todo>(
                                          data: item,
                                          onDragStarted: () => setState(() => _isDraggingTask = true),
                                          onDragEnd: (_) => setState(() => _isDraggingTask = false),
                                          onDraggableCanceled: (_, __) => setState(() => _isDraggingTask = false),
                                          feedback: Material(
                                            color: Colors.transparent,
                                            child: Container(
                                              width: 120,
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: _colorForPriority(item.priority).withValues(alpha: 0.8),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                item.title,
                                                style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                          childWhenDragging: Opacity(opacity: 0.3, child: card),
                                          child: card,
                                        );
                                      },
                                    ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  // ── Day Timeline View ──────────────────────────────────────────────────────
  Widget _buildDayView(ColorScheme scheme) {
    final selectedDate = ref.watch(calendarSelectedDateProvider);
    final allTodos = ref.watch(todosProvider).valueOrNull ?? [];
    final dayTodos = allTodos.where((t) => t.dueDate != null && DateUtils.isSameDay(t.dueDate, selectedDate)).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kPad),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.event_note, color: scheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                '${dayTodos.length} Tasks Scheduled',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: dayTodos.isEmpty
                ? const Center(child: Text('No events scheduled for this day.'))
                : ListView.builder(
                    itemCount: dayTodos.length,
                    itemBuilder: (context, idx) {
                      final todo = dayTodos[idx];
                      final isBlocked = todo.blockedByIds.isNotEmpty && allTodos.any((t) => todo.blockedByIds.contains(t.id) && t.status != TodoStatus.completed);
                      final card = _TodoCard(
                        todo: todo,
                        isBlocked: isBlocked,
                        onToggleStatus: () => ref.read(todosProvider.notifier).toggleTodoStatus(todo.id),
                        onEdit: () => _showEditDialog(todo),
                        onDelete: () => _deleteTodo(todo.id),
                        onAddSubtask: () => _showCreateDialog(parentId: todo.id),
                        hasChildren: false,
                        isCollapsed: false,
                        onToggleCollapse: () {},
                      );
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: LongPressDraggable<Todo>(
                          data: todo,
                          onDragStarted: () => setState(() => _isDraggingTask = true),
                          onDragEnd: (_) => setState(() => _isDraggingTask = false),
                          onDraggableCanceled: (_, __) => setState(() => _isDraggingTask = false),
                          feedback: Material(
                            color: Colors.transparent,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 40),
                              child: Opacity(opacity: 0.9, child: card),
                            ),
                          ),
                          childWhenDragging: Opacity(opacity: 0.3, child: card),
                          child: card,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ── Agenda View ────────────────────────────────────────────────────────────
  Widget _buildAgendaView(ColorScheme scheme) {
    final allTodos = ref.watch(todosProvider).valueOrNull ?? [];
    final datedTodos = allTodos.where((t) => t.dueDate != null).toList();

    // Group dated todos by date
    final Map<DateTime, List<Todo>> grouped = {};
    for (final todo in datedTodos) {
      final localDate = todo.dueDate!.toLocal();
      final day = DateTime(localDate.year, localDate.month, localDate.day);
      grouped.putIfAbsent(day, () => []).add(todo);
    }

    final sortedDates = grouped.keys.toList()..sort();

    if (sortedDates.isEmpty) {
      return const Center(child: Text('No scheduled tasks.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(_kPad, 0, _kPad, 100),
      physics: const BouncingScrollPhysics(),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final date = sortedDates[index];
        final dayTodos = grouped[date] ?? [];
        final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        final dateStr = '${date.day} ${months[date.month - 1]}, ${date.year}';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                dateStr.toUpperCase(),
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            ...dayTodos.map((todo) {
              final isBlocked = todo.blockedByIds.isNotEmpty && allTodos.any((t) => todo.blockedByIds.contains(t.id) && t.status != TodoStatus.completed);
              final card = _TodoCard(
                todo: todo,
                isBlocked: isBlocked,
                onToggleStatus: () => ref.read(todosProvider.notifier).toggleTodoStatus(todo.id),
                onEdit: () => _showEditDialog(todo),
                onDelete: () => _deleteTodo(todo.id),
                onAddSubtask: () => _showCreateDialog(parentId: todo.id),
                hasChildren: false,
                isCollapsed: false,
                onToggleCollapse: () {},
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: LongPressDraggable<Todo>(
                  data: todo,
                  onDragStarted: () => setState(() => _isDraggingTask = true),
                  onDragEnd: (_) => setState(() => _isDraggingTask = false),
                  onDraggableCanceled: (_, __) => setState(() => _isDraggingTask = false),
                  feedback: Material(
                    color: Colors.transparent,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 40),
                      child: Opacity(opacity: 0.9, child: card),
                    ),
                  ),
                  childWhenDragging: Opacity(opacity: 0.3, child: card),
                  child: card,
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildSelectedDateList(DateTime date) {
    final allTodos = ref.watch(todosProvider).valueOrNull ?? [];
    final dayTodos = allTodos.where((t) => t.dueDate != null && DateUtils.isSameDay(t.dueDate, date)).toList();

    if (dayTodos.isEmpty) {
      return const Center(
        child: Text('No tasks scheduled for this day.'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(_kPad),
      itemCount: dayTodos.length,
      itemBuilder: (context, idx) {
        final todo = dayTodos[idx];
        final isBlocked = todo.blockedByIds.isNotEmpty && allTodos.any((t) => todo.blockedByIds.contains(t.id) && t.status != TodoStatus.completed);
        final card = _TodoCard(
          todo: todo,
          isBlocked: isBlocked,
          onToggleStatus: () => ref.read(todosProvider.notifier).toggleTodoStatus(todo.id),
          onEdit: () => _showEditDialog(todo),
          onDelete: () => _deleteTodo(todo.id),
          onAddSubtask: () => _showCreateDialog(parentId: todo.id),
          hasChildren: false,
          isCollapsed: false,
          onToggleCollapse: () {},
        );
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: LongPressDraggable<Todo>(
            data: todo,
            onDragStarted: () => setState(() => _isDraggingTask = true),
            onDragEnd: (_) => setState(() => _isDraggingTask = false),
            onDraggableCanceled: (_, __) => setState(() => _isDraggingTask = false),
            feedback: Material(
              color: Colors.transparent,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 40),
                child: Opacity(opacity: 0.9, child: card),
              ),
            ),
            childWhenDragging: Opacity(opacity: 0.3, child: card),
            child: card,
          ),
        );
      },
    );
  }

  Color _colorForPriority(TodoPriority prio) => switch (prio) {
    TodoPriority.low => const Color(0xFF94A3B8),
    TodoPriority.medium => const Color(0xFFFBBC05),
    TodoPriority.high => const Color(0xFFFB923C),
    TodoPriority.critical => const Color(0xFFFF4D6D),
  };
}

// ── Segment Navigation Tab ───────────────────────────────────────────────────
class _SubViewTab extends StatelessWidget {
  const _SubViewTab({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? scheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Folder Card (Apple Reminders style) ───────────────────────────────────────
class _FolderCard extends StatelessWidget {
  const _FolderCard({
    required this.viewType,
    required this.count,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  final TodoViewType viewType;
  final int count;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected 
              ? scheme.primary.withValues(alpha: 0.15) 
              : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.2),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(viewType.icon, size: 16, color: color),
                ),
                Text(
                  '$count',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: scheme.onSurface,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            Text(
              viewType.label,
              style: textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: scheme.onSurfaceVariant,
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── To-Do Checklist Card Widget ──────────────────────────────────────────────
class _TodoCard extends StatelessWidget {
  const _TodoCard({
    required this.todo,
    required this.onToggleStatus,
    required this.onEdit,
    required this.onDelete,
    required this.onAddSubtask,
    required this.hasChildren,
    required this.isCollapsed,
    required this.onToggleCollapse,
    this.selectionMode = false,
    this.isSelected = false,
    this.onSelectedToggle,
    this.isBlocked = false,
  });

  final Todo todo;
  final VoidCallback onToggleStatus;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAddSubtask;
  final bool hasChildren;
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback? onSelectedToggle;
  final bool isBlocked;

  static Color _colorForPriority(TodoPriority prio) => switch (prio) {
    TodoPriority.low => const Color(0xFF94A3B8),
    TodoPriority.medium => const Color(0xFFFBBC05),
    TodoPriority.high => const Color(0xFFFB923C),
    TodoPriority.critical => const Color(0xFFFF4D6D),
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final isOverdue = todo.dueDate != null && 
        todo.dueDate!.isBefore(DateTime.now().subtract(const Duration(days: 1))) && 
        !todo.isCompleted;

    final checklistItems = TodoChecklistParser.parse(todo.notes);
    final hasChecklist = checklistItems.isNotEmpty;
    final totalChecklist = checklistItems.length;
    final completedChecklist = checklistItems.where((i) => i.isChecked).length;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left priority accent bar
          Container(
            width: 5,
            height: 52,
            decoration: BoxDecoration(
              color: _colorForPriority(todo.priority),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Collapsible indicator (if has subtasks)
          if (hasChildren)
            IconButton(
              icon: Icon(
                isCollapsed ? Icons.keyboard_arrow_right_rounded : Icons.keyboard_arrow_down_rounded,
                size: 20,
              ),
              onPressed: onToggleCollapse,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            )
          else
            const SizedBox(width: 12),

          // Custom styled checkbox
          GestureDetector(
            onTap: selectionMode ? onSelectedToggle : onToggleStatus,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selectionMode
                      ? (isSelected ? scheme.primary : scheme.outline)
                      : (todo.isCompleted ? Colors.green : (isBlocked ? scheme.error : _colorForPriority(todo.priority))),
                  width: 2.0,
                ),
                color: selectionMode
                    ? (isSelected ? scheme.primary.withValues(alpha: 0.15) : Colors.transparent)
                    : (todo.isCompleted ? Colors.green.withValues(alpha: 0.15) : Colors.transparent),
              ),
              child: selectionMode
                  ? (isSelected
                      ? Center(
                          child: Icon(Icons.check_rounded, size: 12, color: scheme.primary),
                        )
                      : null)
                  : (todo.isCompleted
                      ? const Center(
                          child: Icon(Icons.check, size: 12, color: Colors.green),
                        )
                      : (isBlocked
                          ? Center(
                              child: Icon(Icons.lock_rounded, size: 10, color: scheme.error),
                            )
                          : null)),
            ),
          ),
          const SizedBox(width: 14),

          // To-Do Body details
          Expanded(
            child: GestureDetector(
              onTap: selectionMode ? onSelectedToggle : onEdit,
              behavior: HitTestBehavior.opaque,
              child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    todo.title,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
                      color: todo.isCompleted 
                          ? scheme.onSurfaceVariant.withValues(alpha: 0.6) 
                          : scheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (todo.notes != null && todo.notes!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      todo.notes!,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (hasChecklist) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.check_box_outlined, size: 12, color: scheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          '$completedChecklist/$totalChecklist',
                          style: textTheme.bodySmall?.copyWith(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: totalChecklist > 0 ? completedChecklist / totalChecklist : 0.0,
                              minHeight: 4,
                              backgroundColor: scheme.primary.withValues(alpha: 0.1),
                              color: scheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (todo.tags.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: todo.tags.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: scheme.primary.withValues(alpha: 0.15)),
                          ),
                          child: Text(
                            '#$tag',
                            style: textTheme.labelSmall?.copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: scheme.primary,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  if (todo.dueDate != null || todo.category != null || todo.recurrence != null || isBlocked || todo.estimatedMinutes > 0 || todo.energyLevel != TodoEnergyLevel.medium) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (isBlocked) ...[
                          Icon(Icons.lock_outline_rounded, size: 11, color: scheme.error),
                          const SizedBox(width: 2),
                          Text(
                            'BLOCKED',
                            style: textTheme.bodySmall?.copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: scheme.error,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (todo.estimatedMinutes > 0) ...[
                          Icon(Icons.timer_outlined, size: 11, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 2),
                          Text(
                            todo.estimatedMinutes >= 60
                                ? '${(todo.estimatedMinutes / 60).toStringAsFixed(1).replaceAll('.0', '')}h'
                                : '${todo.estimatedMinutes}m',
                            style: textTheme.bodySmall?.copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (todo.energyLevel != TodoEnergyLevel.medium) ...[
                          Icon(Icons.bolt_rounded, size: 11, color: Colors.orangeAccent),
                          const SizedBox(width: 2),
                          Text(
                            todo.energyLevel.name.toUpperCase(),
                            style: textTheme.bodySmall?.copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.orangeAccent,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (todo.dueDate != null) ...[
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 10,
                            color: isOverdue ? scheme.error : scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDueDate(todo.dueDate!),
                            style: textTheme.bodySmall?.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isOverdue ? scheme.error : scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (todo.recurrence != null) ...[
                          Icon(Icons.replay_rounded, size: 11, color: scheme.primary),
                          const SizedBox(width: 2),
                          Text(
                            todo.recurrence!.toUpperCase(),
                            style: textTheme.bodySmall?.copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: scheme.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (todo.category != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              todo.category!.toUpperCase(),
                              style: textTheme.labelSmall?.copyWith(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: scheme.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Popeup Menu Actions
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: scheme.onSurfaceVariant, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onSelected: (val) {
              if (val == 'edit') {
                onEdit();
              } else if (val == 'delete') {
                onDelete();
              } else if (val == 'subtask') {
                onAddSubtask();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'subtask',
                child: Row(
                  children: [
                    Icon(Icons.add_circle_outline, color: scheme.onSurface, size: 18),
                    const SizedBox(width: 8),
                    const Text('Add Subtask'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_rounded, color: scheme.onSurface, size: 18),
                    const SizedBox(width: 8),
                    const Text('Edit Task'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_rounded, color: scheme.error, size: 18),
                    const SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: scheme.error)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }

  String _formatDueDate(DateTime dt) {
    final local = dt.toLocal();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${local.day} ${months[local.month - 1]}';
  }
}

// ── Reusable empty To-Dos view state ──────────────────────────────────────────
class _NoTodosView extends StatelessWidget {
  const _NoTodosView();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.playlist_add_check_rounded,
              size: 48,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'All tasks complete! Good job.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bottom Sheet Filters manager ─────────────────────────────────────────────
class _FilterBottomSheet extends ConsumerWidget {
  const _FilterBottomSheet({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(todoFiltersProvider);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'FILTER TASKS',
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {
                  ref.read(soundServiceProvider).buttonPress();
                  ref.read(hapticServiceProvider).buttonPress();
                  ref.read(todoFiltersProvider.notifier).state = const TodoFilters();
                  Navigator.pop(context);
                },
                child: const Text('Reset All'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Priority Filter
          Text('PRIORITY', style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              GestureDetector(
                onTap: () {
                  ref.read(todoFiltersProvider.notifier).state = filters.copyWith(clearPriority: true);
                },
                child: Chip(
                  label: const Text('All'),
                  backgroundColor: filters.priority == null ? scheme.primary : Colors.transparent,
                  labelStyle: TextStyle(color: filters.priority == null ? scheme.onPrimary : scheme.onSurface),
                  side: BorderSide(color: filters.priority == null ? scheme.primary : scheme.outlineVariant),
                ),
              ),
              ...TodoPriority.values.map((prio) {
                final isSel = filters.priority == prio;
                return GestureDetector(
                  onTap: () {
                    ref.read(soundServiceProvider).buttonPress();
                    ref.read(hapticServiceProvider).buttonPress();
                    ref.read(todoFiltersProvider.notifier).state = filters.copyWith(priority: prio);
                  },
                  child: Chip(
                    label: Text(prio.label),
                    backgroundColor: isSel ? scheme.primary : Colors.transparent,
                    labelStyle: TextStyle(color: isSel ? scheme.onPrimary : scheme.onSurface),
                    side: BorderSide(color: isSel ? scheme.primary : scheme.outlineVariant),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 16),

          // Status Filter
          Text('STATUS', style: textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              GestureDetector(
                onTap: () {
                  ref.read(todoFiltersProvider.notifier).state = filters.copyWith(clearStatus: true);
                },
                child: Chip(
                  label: const Text('All'),
                  backgroundColor: filters.status == null ? scheme.primary : Colors.transparent,
                  labelStyle: TextStyle(color: filters.status == null ? scheme.onPrimary : scheme.onSurface),
                  side: BorderSide(color: filters.status == null ? scheme.primary : scheme.outlineVariant),
                ),
              ),
              ...TodoStatus.values.map((status) {
                final isSel = filters.status == status;
                return GestureDetector(
                  onTap: () {
                    ref.read(soundServiceProvider).buttonPress();
                    ref.read(hapticServiceProvider).buttonPress();
                    ref.read(todoFiltersProvider.notifier).state = filters.copyWith(status: status);
                  },
                  child: Chip(
                    label: Text(status.label),
                    backgroundColor: isSel ? scheme.primary : Colors.transparent,
                    labelStyle: TextStyle(color: isSel ? scheme.onPrimary : scheme.onSurface),
                    side: BorderSide(color: isSel ? scheme.primary : scheme.outlineVariant),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 24),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('APPLY FILTERS'),
          ),
        ],
      ),
    );
  }
}

// ── Dialog to Create or Edit To-Dos ──────────────────────────────────────────
class _CreateEditTodoDialog extends StatefulWidget {
  const _CreateEditTodoDialog({
    this.todo,
    this.parentId,
    this.prefilledDate,
    required this.ref,
  });

  final Todo? todo;
  final String? parentId;
  final DateTime? prefilledDate;
  final WidgetRef ref;

  @override
  State<_CreateEditTodoDialog> createState() => _CreateEditTodoDialogState();
}

class _CreateEditTodoDialogState extends State<_CreateEditTodoDialog> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _categoryController = TextEditingController();
  final _estimatedMinutesController = TextEditingController(text: '0');
  
  TodoPriority _priority = TodoPriority.medium;
  TodoStatus _status = TodoStatus.pending;
  DateTime? _dueDate;
  DateTime? _reminderTime;
  String? _recurrence;
  String? _selectedProjectId;
  String? _selectedGoalId;

  // Premium fields
  TodoEnergyLevel _energyLevel = TodoEnergyLevel.medium;
  List<String> _tags = [];
  List<DateTime> _reminderTimes = [];
  List<String> _blockedByIds = [];

  bool _isSaving = false;
  ParsedTodoNli? _nliPreview;

  @override
  void initState() {
    super.initState();
    _dueDate = widget.prefilledDate;
    if (widget.todo != null) {
      final t = widget.todo!;
      _titleController.text = t.title;
      _notesController.text = t.notes ?? '';
      _categoryController.text = t.category ?? '';
      _estimatedMinutesController.text = '${t.estimatedMinutes}';
      _priority = t.priority;
      _status = t.status;
      _dueDate = t.dueDate;
      _reminderTime = t.reminderTime;
      _recurrence = t.recurrence;
      _selectedProjectId = t.projectId;
      _selectedGoalId = t.goalId;
      _energyLevel = t.energyLevel;
      _tags = List<String>.from(t.tags);
      _reminderTimes = List<DateTime>.from(t.reminderTimes);
      _blockedByIds = List<String>.from(t.blockedByIds);
    }
    _titleController.addListener(_updateNliPreview);
  }

  void _updateNliPreview() {
    final text = _titleController.text.trim();
    if (text.isEmpty) {
      setState(() => _nliPreview = null);
      return;
    }
    final parsed = TodoNliParser.parse(text);
    if (parsed.dueDate != null || 
        parsed.recurrence != null || 
        parsed.priority != TodoPriority.medium || 
        parsed.reminderTime != null || 
        parsed.tags.isNotEmpty) {
      setState(() {
        _nliPreview = parsed;
      });
    } else {
      setState(() => _nliPreview = null);
    }
  }

  String _formatNliDate(DateTime dt) {
    final local = dt.toLocal();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final timeStr = dt.hour != 0 || dt.minute != 0 
        ? ' at ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}' 
        : '';
    return '${local.day} ${months[local.month - 1]}$timeStr';
  }

  @override
  void dispose() {
    _titleController.removeListener(_updateNliPreview);
    _titleController.dispose();
    _notesController.dispose();
    _categoryController.dispose();
    _estimatedMinutesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final notifier = widget.ref.read(todosProvider.notifier);

    final notesVal = _notesController.text.trim();
    final catVal = _categoryController.text.trim();
    final estMins = int.tryParse(_estimatedMinutesController.text.trim()) ?? 0;

    try {
      if (widget.todo == null) {
        await notifier.createTodo(
          title: title,
          notes: notesVal.isEmpty ? null : notesVal,
          status: _status,
          priority: _priority,
          category: catVal.isEmpty ? null : catVal,
          dueDate: _dueDate,
          reminderTime: _reminderTime,
          estimatedMinutes: estMins,
          projectId: _selectedProjectId,
          goalId: _selectedGoalId,
          recurrence: _recurrence,
          parentId: widget.parentId,
          energyLevel: _energyLevel,
          tags: _tags,
          reminderTimes: _reminderTimes,
          blockedByIds: _blockedByIds,
        );
      } else {
        await notifier.updateTodo(
          id: widget.todo!.id,
          title: title,
          notes: notesVal,
          status: _status,
          priority: _priority,
          category: catVal,
          dueDate: _dueDate,
          reminderTime: _reminderTime,
          estimatedMinutes: estMins,
          projectId: _selectedProjectId,
          goalId: _selectedGoalId,
          recurrence: _recurrence,
          energyLevel: _energyLevel,
          tags: _tags,
          reminderTimes: _reminderTimes,
          blockedByIds: _blockedByIds,
          clearDueDate: _dueDate == null,
          clearReminderTime: _reminderTime == null,
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: ${ErrorMessageMapper.fromError(e)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final allTodos = widget.ref.watch(todosProvider).valueOrNull ?? [];
    final projects = widget.ref.watch(projectsProvider).valueOrNull ?? [];
    final goals = widget.ref.watch(goalsProvider).valueOrNull ?? [];

    // Filter out completed tasks and this task to find potential blockers
    final potentialBlockers = allTodos.where((t) => t.id != widget.todo?.id && t.status != TodoStatus.completed).toList();

    // Notes checklist parsing
    final checklistItems = TodoChecklistParser.parse(_notesController.text);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(widget.todo == null ? 'New To-Do Task' : 'Edit To-Do Details'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('TITLE *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            const SizedBox(height: 6),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                hintText: 'Buy groceries, run 5k...',
              ),
            ),
            const SizedBox(height: 14),

            if (_nliPreview != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.primary.withValues(alpha: 0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.auto_awesome_rounded, size: 14, color: scheme.primary),
                            const SizedBox(width: 6),
                            Text(
                              'SMART SUGGESTIONS',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                                color: scheme.primary,
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            widget.ref.read(soundServiceProvider).buttonPress();
                            widget.ref.read(hapticServiceProvider).buttonPress();
                            setState(() {
                              if (_nliPreview!.dueDate != null) {
                                _dueDate = _nliPreview!.dueDate;
                              }
                              if (_nliPreview!.reminderTime != null) {
                                _reminderTime = _nliPreview!.reminderTime;
                              }
                              if (_nliPreview!.recurrence != null) {
                                _recurrence = _nliPreview!.recurrence;
                              }
                              if (_nliPreview!.priority != TodoPriority.medium) {
                                _priority = _nliPreview!.priority;
                              }
                              if (_nliPreview!.tags.isNotEmpty) {
                                for (final tag in _nliPreview!.tags) {
                                  if (!_tags.contains(tag)) {
                                    _tags.add(tag);
                                  }
                                }
                              }
                            });
                          },
                          child: Text(
                            'APPLY ALL',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: scheme.primary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (_nliPreview!.dueDate != null)
                          _SuggestionChip(
                            icon: Icons.calendar_today_rounded,
                            label: _formatNliDate(_nliPreview!.dueDate!),
                            onTap: () {
                              setState(() {
                                _dueDate = _nliPreview!.dueDate;
                                if (_nliPreview!.reminderTime != null) {
                                  _reminderTime = _nliPreview!.reminderTime;
                                }
                              });
                            },
                          ),
                        if (_nliPreview!.recurrence != null)
                          _SuggestionChip(
                            icon: Icons.replay_rounded,
                            label: _nliPreview!.recurrence!.toUpperCase(),
                            onTap: () {
                              setState(() {
                                _recurrence = _nliPreview!.recurrence;
                              });
                            },
                          ),
                        if (_nliPreview!.priority != TodoPriority.medium)
                          _SuggestionChip(
                            icon: Icons.priority_high_rounded,
                            label: _nliPreview!.priority.label,
                            onTap: () {
                              setState(() {
                                _priority = _nliPreview!.priority;
                              });
                            },
                          ),
                        if (_nliPreview!.tags.isNotEmpty)
                          ..._nliPreview!.tags.map((tag) => _SuggestionChip(
                            icon: Icons.tag_rounded,
                            label: '#$tag',
                            onTap: () {
                              setState(() {
                                if (!_tags.contains(tag)) {
                                  _tags.add(tag);
                                }
                              });
                            },
                          )),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tap suggestions to apply individually, or APPLY ALL.',
                      style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            const Text('NOTES & CHECKLISTS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            const SizedBox(height: 6),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                hintText: 'Add description details or markdown checklist...',
              ),
            ),
            const SizedBox(height: 4),
            
            // Interactive checklist items view
            if (checklistItems.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('CHECKLIST', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                    ...checklistItems.map((item) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            SizedBox(
                              height: 24,
                              width: 24,
                              child: Checkbox(
                                value: item.isChecked,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                onChanged: (val) {
                                  setState(() {
                                    _notesController.text = TodoChecklistParser.toggle(_notesController.text, item.lineIndex);
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.text,
                                style: TextStyle(
                                  fontSize: 12,
                                  decoration: item.isChecked ? TextDecoration.lineThrough : null,
                                  color: item.isChecked ? scheme.onSurfaceVariant.withValues(alpha: 0.6) : scheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
            TextButton.icon(
              icon: const Icon(Icons.add_box_outlined, size: 16),
              label: const Text('Add Action Item'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                minimumSize: Size.zero,
              ),
              onPressed: () {
                final currentText = _notesController.text;
                final suffix = currentText.isEmpty ? '[ ] ' : '\n[ ] ';
                setState(() {
                  _notesController.text = currentText + suffix;
                });
              },
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('PRIORITY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<TodoPriority>(
                        initialValue: _priority,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        items: TodoPriority.values.map((prio) {
                          return DropdownMenuItem(value: prio, child: Text(prio.label));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _priority = val);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<TodoStatus>(
                        initialValue: _status,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        items: TodoStatus.values.map((status) {
                          return DropdownMenuItem(value: status, child: Text(status.label));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _status = val);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ENERGY LEVEL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<TodoEnergyLevel>(
                        initialValue: _energyLevel,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        items: TodoEnergyLevel.values.map((energy) {
                          return DropdownMenuItem(value: energy, child: Text(energy.label));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _energyLevel = val);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('RECURRENCE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String?>(
                        value: _recurrence,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('None')),
                          DropdownMenuItem(value: 'daily', child: Text('Daily')),
                          DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                          DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                        ],
                        onChanged: (val) => setState(() => _recurrence = val),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('DUE DATE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _dueDate ?? DateTime.now(),
                            firstDate: DateTime(2025),
                            lastDate: DateTime(2035),
                          );
                          if (date != null) setState(() => _dueDate = date);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: scheme.outline),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _dueDate == null 
                                    ? 'Select Date' 
                                    : '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}',
                              ),
                              if (_dueDate != null)
                                GestureDetector(
                                  onTap: () => setState(() => _dueDate = null),
                                  child: const Icon(Icons.close, size: 16),
                                )
                              else
                                const Icon(Icons.calendar_today, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('REMINDER TIME', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(_reminderTime ?? DateTime.now()),
                          );
                          if (time != null) {
                            final baseDate = _dueDate ?? DateTime.now();
                            setState(() {
                              _reminderTime = DateTime(
                                baseDate.year,
                                baseDate.month,
                                baseDate.day,
                                time.hour,
                                time.minute,
                              );
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: scheme.outline),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _reminderTime == null 
                                    ? 'No Reminder' 
                                    : '${_reminderTime!.hour.toString().padLeft(2, '0')}:${_reminderTime!.minute.toString().padLeft(2, '0')}',
                              ),
                              if (_reminderTime != null)
                                GestureDetector(
                                  onTap: () => setState(() => _reminderTime = null),
                                  child: const Icon(Icons.close, size: 16),
                                )
                              else
                                const Icon(Icons.access_time, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Multiple Reminders
            const Text('ADDITIONAL REMINDERS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _reminderTimes.asMap().entries.map((entry) {
                final idx = entry.key;
                final time = entry.value;
                return Chip(
                  label: Text('${time.day}/${time.month} at ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'),
                  onDeleted: () {
                    setState(() => _reminderTimes.removeAt(idx));
                  },
                );
              }).toList(),
            ),
            TextButton.icon(
              icon: const Icon(Icons.add_alarm_rounded, size: 16),
              label: const Text('Add Reminder'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                minimumSize: Size.zero,
              ),
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _dueDate ?? DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                  lastDate: DateTime(2035),
                );
                if (date == null) return;
                if (!context.mounted) return;
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (time == null) return;
                setState(() {
                  _reminderTimes.add(DateTime(date.year, date.month, date.day, time.hour, time.minute));
                });
              },
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ESTIMATED TIME', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        value: [0, 15, 30, 45, 60, 120].contains(int.tryParse(_estimatedMinutesController.text) ?? 0)
                            ? (int.tryParse(_estimatedMinutesController.text) ?? 0)
                            : -1,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        items: const [
                          DropdownMenuItem(value: 0, child: Text('None')),
                          DropdownMenuItem(value: 15, child: Text('15 min')),
                          DropdownMenuItem(value: 30, child: Text('30 min')),
                          DropdownMenuItem(value: 45, child: Text('45 min')),
                          DropdownMenuItem(value: 60, child: Text('1 hour')),
                          DropdownMenuItem(value: 120, child: Text('2 hours')),
                          DropdownMenuItem(value: -1, child: Text('Custom')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              if (val >= 0) {
                                _estimatedMinutesController.text = '$val';
                              }
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('CATEGORY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _categoryController,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          hintText: 'Work, Personal...',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (![0, 15, 30, 45, 60, 120].contains(int.tryParse(_estimatedMinutesController.text) ?? 0)) ...[
              const SizedBox(height: 10),
              const Text('CUSTOM ESTIMATED MINUTES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
              const SizedBox(height: 4),
              TextField(
                controller: _estimatedMinutesController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  suffixText: 'mins',
                ),
              ),
            ],
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('PROJECT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String?>(
                        value: _selectedProjectId,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('None')),
                          ...projects.map((p) => DropdownMenuItem(value: p.id, child: Text(p.title))),
                        ],
                        onChanged: (val) => setState(() => _selectedProjectId = val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('LINKED GOAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String?>(
                        value: _selectedGoalId,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('None')),
                          ...goals.map((g) => DropdownMenuItem(value: g.goal.id, child: Text(g.goal.title))),
                        ],
                        onChanged: (val) => setState(() => _selectedGoalId = val),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Blockers section
            const Text('BLOCKED BY (DEPENDENCIES)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _blockedByIds.map((id) {
                final blockerTodo = allTodos.firstWhere((t) => t.id == id, orElse: () => Todo(id: id, userId: '', title: 'Unknown Task'));
                return Chip(
                  label: Text(blockerTodo.title, style: const TextStyle(fontSize: 11)),
                  onDeleted: () {
                    setState(() => _blockedByIds.remove(id));
                  },
                );
              }).toList(),
            ),
            if (potentialBlockers.isNotEmpty) ...[
              TextButton.icon(
                icon: const Icon(Icons.link_rounded, size: 16),
                label: const Text('Add Dependency'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  minimumSize: Size.zero,
                ),
                onPressed: () async {
                  final selected = await showDialog<String>(
                    context: context,
                    builder: (context) => SimpleDialog(
                      title: const Text('Select Blocker Task'),
                      children: potentialBlockers.where((t) => !_blockedByIds.contains(t.id)).map((t) {
                        return SimpleDialogOption(
                          onPressed: () => Navigator.pop(context, t.id),
                          child: Text(t.title),
                        );
                      }).toList(),
                    ),
                  );
                  if (selected != null) {
                    setState(() => _blockedByIds.add(selected));
                  }
                },
              ),
            ],
            const SizedBox(height: 14),

            // Tags section
            const Text('TAGS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _tags.map((tag) {
                return Chip(
                  label: Text('#$tag', style: const TextStyle(fontSize: 11)),
                  onDeleted: () {
                    setState(() => _tags.remove(tag));
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 6),
            TextField(
              decoration: InputDecoration(
                hintText: 'Type tag and press Enter...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onSubmitted: (val) {
                final tag = val.trim().replaceAll('#', '').toLowerCase();
                if (tag.isNotEmpty && !_tags.contains(tag)) {
                  setState(() {
                    _tags.add(tag);
                  });
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _isSaving ? null : _save,
          child: _isSaving 
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
              : const Text('Save'),
        ),
      ],
    );
  }
}

class TodoDragTargetWrapper extends StatefulWidget {
  const TodoDragTargetWrapper({
    super.key,
    required this.todo,
    required this.child,
    required this.onReorder,
    required this.onMakeSubtask,
  });

  final Todo todo;
  final Widget child;
  final Function(Todo dragged, Todo target, bool before) onReorder;
  final Function(Todo dragged, Todo newParent) onMakeSubtask;

  @override
  State<TodoDragTargetWrapper> createState() => _TodoDragTargetWrapperState();
}

class _TodoDragTargetWrapperState extends State<TodoDragTargetWrapper> {
  bool _isOverTop = false;
  bool _isOverMiddle = false;
  bool _isOverBottom = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Drop Zone
        DragTarget<Todo>(
          onWillAcceptWithDetails: (details) => details.data.id != widget.todo.id,
          onAcceptWithDetails: (details) {
            widget.onReorder(details.data, widget.todo, true);
          },
          onMove: (_) => setState(() => _isOverTop = true),
          onLeave: (_) => setState(() => _isOverTop = false),
          builder: (context, candidateData, rejectedData) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: _isOverTop ? 12 : 4,
              color: _isOverTop ? scheme.primary.withValues(alpha: 0.8) : Colors.transparent,
            );
          },
        ),

        // Middle Card Zone
        DragTarget<Todo>(
          onWillAcceptWithDetails: (details) {
            if (details.data.id == widget.todo.id) return false;
            bool isDescendant(Todo current, String idToFind) {
              if (current.id == idToFind) return true;
              return current.subtasks.any((sub) => isDescendant(sub, idToFind));
            }
            if (isDescendant(details.data, widget.todo.id)) return false;
            return true;
          },
          onAcceptWithDetails: (details) {
            widget.onMakeSubtask(details.data, widget.todo);
          },
          onMove: (_) => setState(() => _isOverMiddle = true),
          onLeave: (_) => setState(() => _isOverMiddle = false),
          builder: (context, candidateData, rejectedData) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: _isOverMiddle 
                    ? Border.all(color: scheme.primary, width: 2) 
                    : Border.all(color: Colors.transparent, width: 2),
              ),
              child: widget.child,
            );
          },
        ),

        // Bottom Drop Zone
        DragTarget<Todo>(
          onWillAcceptWithDetails: (details) => details.data.id != widget.todo.id,
          onAcceptWithDetails: (details) {
            widget.onReorder(details.data, widget.todo, false);
          },
          onMove: (_) => setState(() => _isOverBottom = true),
          onLeave: (_) => setState(() => _isOverBottom = false),
          builder: (context, candidateData, rejectedData) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: _isOverBottom ? 12 : 4,
              color: _isOverBottom ? scheme.primary.withValues(alpha: 0.8) : Colors.transparent,
            );
          },
        ),
      ],
    );
  }
}

class _BatchActionButton extends StatelessWidget {
  const _BatchActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textColor = color ?? scheme.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: textColor),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: scheme.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: scheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Floating Quick Add Bottom Sheet ──────────────────────────────────────────
class _QuickAddBottomSheet extends StatefulWidget {
  const _QuickAddBottomSheet({required this.ref});
  final WidgetRef ref;

  @override
  State<_QuickAddBottomSheet> createState() => _QuickAddBottomSheetState();
}

class _QuickAddBottomSheetState extends State<_QuickAddBottomSheet> {
  final _controller = TextEditingController();
  ParsedTodoNli? _parsed;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _parsed = null);
      return;
    }
    setState(() {
      _parsed = TodoNliParser.parse(text);
    });
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final parsed = TodoNliParser.parse(text);
    final notifier = widget.ref.read(todosProvider.notifier);

    widget.ref.read(soundServiceProvider).buttonPress();
    widget.ref.read(hapticServiceProvider).buttonPress();

    try {
      await notifier.createTodo(
        title: parsed.title,
        dueDate: parsed.dueDate,
        reminderTime: parsed.reminderTime,
        recurrence: parsed.recurrence,
        priority: parsed.priority,
        tags: parsed.tags,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add: $e')),
        );
      }
    }
  }

  String _formatNliDate(DateTime dt) {
    final local = dt.toLocal();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final timeStr = dt.hour != 0 || dt.minute != 0 
        ? ' at ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}' 
        : '';
    return '${local.day} ${months[local.month - 1]}$timeStr';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -2)),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    style: textTheme.bodyLarge,
                    decoration: InputDecoration(
                      hintText: 'e.g. Study DSA tomorrow 7 PM #exam',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send_rounded, color: scheme.primary),
                  onPressed: _submit,
                ),
              ],
            ),
            if (_parsed != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (_parsed!.dueDate != null)
                    Chip(
                      avatar: const Icon(Icons.calendar_today_rounded, size: 12),
                      label: Text(_formatNliDate(_parsed!.dueDate!), style: const TextStyle(fontSize: 10)),
                    ),
                  if (_parsed!.recurrence != null)
                    Chip(
                      avatar: const Icon(Icons.replay_rounded, size: 12),
                      label: Text(_parsed!.recurrence!.toUpperCase(), style: const TextStyle(fontSize: 10)),
                    ),
                  if (_parsed!.priority != TodoPriority.medium)
                    Chip(
                      avatar: const Icon(Icons.priority_high_rounded, size: 12),
                      label: Text(_parsed!.priority.label, style: const TextStyle(fontSize: 10)),
                    ),
                  if (_parsed!.tags.isNotEmpty)
                    ..._parsed!.tags.map((tag) => Chip(
                      avatar: const Icon(Icons.tag_rounded, size: 12),
                      label: Text('#$tag', style: const TextStyle(fontSize: 10)),
                    )),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

