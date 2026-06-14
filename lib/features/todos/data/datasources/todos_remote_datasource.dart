import 'package:chronyx/features/todos/data/models/todo_model.dart';
import 'package:chronyx/features/todos/domain/entities/todo.dart';
import 'package:chronyx/features/todos/data/models/todo_attachment_model.dart';
import 'package:chronyx/features/todos/domain/entities/todo_attachment.dart';

abstract class TodosRemoteDataSource {
  Future<List<TodoModel>> fetchTodos();
  Future<TodoModel> createTodo({
    required String title,
    String? notes,
    TodoStatus status = TodoStatus.pending,
    TodoPriority priority = TodoPriority.medium,
    String? category,
    DateTime? dueDate,
    DateTime? reminderTime,
    int estimatedMinutes = 0,
    String? projectId,
    String? goalId,
    String? habitId,
    String? recurrence,
    String? parentId,
    TodoEnergyLevel energyLevel = TodoEnergyLevel.medium,
    List<String> tags = const [],
    List<DateTime> reminderTimes = const [],
    List<String> blockedByIds = const [],
  });
  Future<TodoModel> updateTodo({
    required String id,
    String? title,
    String? notes,
    TodoStatus? status,
    TodoPriority? priority,
    String? category,
    DateTime? dueDate,
    DateTime? reminderTime,
    int? estimatedMinutes,
    String? projectId,
    String? goalId,
    String? habitId,
    String? recurrence,
    String? parentId,
    TodoEnergyLevel? energyLevel,
    List<String>? tags,
    List<DateTime>? reminderTimes,
    List<String>? blockedByIds,
    bool clearDueDate = false,
    bool clearReminderTime = false,
    bool clearParentId = false,
  });
  Future<void> deleteTodo({required String id});

  // Attachments
  Future<List<TodoAttachmentModel>> fetchAttachments({required String todoId});
  Future<TodoAttachmentModel> createAttachment({
    required String todoId,
    required String name,
    required String url,
    required TodoAttachmentType type,
    int? sizeBytes,
  });
  Future<void> deleteAttachment({required String attachmentId});
}

