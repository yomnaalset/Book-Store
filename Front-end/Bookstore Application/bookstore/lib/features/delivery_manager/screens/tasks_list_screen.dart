import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/translations.dart';
import '../../../core/constants/app_colors.dart';
import '../models/delivery_task.dart';
import '../providers/delivery_tasks_provider.dart';
import '../widgets/task_list_tile.dart';
import '../widgets/task_filter_chip.dart';
import 'task_detail_screen.dart';

class TasksListScreen extends StatefulWidget {
  final String? filter;

  const TasksListScreen({super.key, this.filter});

  @override
  State<TasksListScreen> createState() => _TasksListScreenState();
}

class _TasksListScreenState extends State<TasksListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _currentFilter = 'all';

  @override
  void initState() {
    super.initState();
    if (widget.filter != null) {
      _currentFilter = widget.filter!;
    }

    // Load tasks when the screen is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('TasksListScreen: initState - calling loadTasks');
      Provider.of<DeliveryTasksProvider>(context, listen: false).loadTasks();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(AppTranslations.t(context, 'task_list')),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              Provider.of<DeliveryTasksProvider>(
                context,
                listen: false,
              ).loadTasks();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            color: AppColors.primary,
            child: Column(
              children: [
                // Search Bar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: AppTranslations.t(context, 'search'),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                Provider.of<DeliveryTasksProvider>(
                                  context,
                                  listen: false,
                                ).loadTasks();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey.shade800
                          : AppColors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) {
                      Provider.of<DeliveryTasksProvider>(
                        context,
                        listen: false,
                      ).loadTasks();
                    },
                  ),
                ),
                // Filter Chips
                _buildFilterChips(),
              ],
            ),
          ),
          // Tasks List
          Expanded(
            child: Consumer<DeliveryTasksProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.error != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          provider.error!,
                          style: TextStyle(
                            fontSize: 16,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            provider.loadTasks();
                          },
                          child: Text(AppTranslations.t(context, 'retry')),
                        ),
                      ],
                    ),
                  );
                }

                final filteredTasks = _getFilteredTasks(provider.tasks);

                if (filteredTasks.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 64,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _getEmptyMessage(),
                          style: TextStyle(
                            fontSize: 16,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            provider.loadTasks();
                          },
                          child: Text(AppTranslations.t(context, 'refresh')),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => provider.loadTasks(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredTasks.length,
                    itemBuilder: (context, index) {
                      final task = filteredTasks[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TaskListTile(
                          task: task,
                          isUrgent: task.status == DeliveryTask.statusFailed,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    TaskDetailScreen(task: task),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      {'key': 'all', 'label': AppTranslations.t(context, 'all')},
      {'key': 'assigned', 'label': AppTranslations.t(context, 'assigned')},
      {'key': 'accepted', 'label': AppTranslations.t(context, 'accepted')},
      {'key': 'picked_up', 'label': AppTranslations.t(context, 'picked_up')},
      {'key': 'in_transit', 'label': AppTranslations.t(context, 'in_transit')},
      {'key': 'delivered', 'label': AppTranslations.t(context, 'delivered')},
      {'key': 'completed', 'label': AppTranslations.t(context, 'completed')},
      {'key': 'failed', 'label': AppTranslations.t(context, 'failed')},
    ];

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _currentFilter == filter['key'];

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TaskFilterChip(
              label: filter['label']!,
              isSelected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _currentFilter = filter['key']!;
                  });
                }
              },
            ),
          );
        },
      ),
    );
  }

  List<DeliveryTask> _getFilteredTasks(List<DeliveryTask> tasks) {
    if (_currentFilter == 'all') {
      return tasks;
    }

    return tasks.where((task) {
      switch (_currentFilter) {
        case 'assigned':
          return task.status == DeliveryTask.statusAccepted;
        case 'accepted':
          return task.status == DeliveryTask.statusAccepted;
        case 'picked_up':
          return task.status == DeliveryTask.statusInProgress &&
              task.pickedUpAt != null;
        case 'in_transit':
          return task.status == DeliveryTask.statusInProgress &&
              task.pickedUpAt != null &&
              task.deliveredAt == null;
        case 'delivered':
          return task.status == DeliveryTask.statusDelivered;
        case 'completed':
          return task.status == DeliveryTask.statusCompleted;
        case 'failed':
          return task.status == DeliveryTask.statusFailed;
        default:
          return true;
      }
    }).toList();
  }

  String _getEmptyMessage() {
    switch (_currentFilter) {
      case 'assigned':
        return 'No assigned tasks';
      case 'accepted':
        return 'No accepted tasks';
      case 'picked_up':
        return 'No picked up tasks';
      case 'in_transit':
        return 'No tasks in transit';
      case 'delivered':
        return 'No delivered tasks';
      case 'completed':
        return 'No completed tasks';
      case 'failed':
        return 'No failed tasks';
      default:
        return 'No tasks found';
    }
  }
}
