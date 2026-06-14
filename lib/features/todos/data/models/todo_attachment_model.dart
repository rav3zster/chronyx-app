import 'package:chronyx/features/todos/domain/entities/todo_attachment.dart';

class TodoAttachmentModel {
  const TodoAttachmentModel({
    required this.id,
    required this.todoId,
    required this.name,
    required this.url,
    required this.type,
    this.sizeBytes,
    required this.createdAt,
  });

  final String id;
  final String todoId;
  final String name;
  final String url;
  final TodoAttachmentType type;
  final int? sizeBytes;
  final DateTime createdAt;

  factory TodoAttachmentModel.fromJson(Map<String, dynamic> json) {
    return TodoAttachmentModel(
      id: json['id'] as String,
      todoId: json['todo_id'] as String,
      name: json['name'] as String? ?? '',
      url: json['url'] as String? ?? '',
      type: TodoAttachmentType.fromJson(json['type'] as String?),
      sizeBytes: (json['size_bytes'] as num?)?.toInt(),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'todo_id': todoId,
      'name': name,
      'url': url,
      'type': type.jsonKey,
      'size_bytes': sizeBytes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  TodoAttachment toEntity() {
    return TodoAttachment(
      id: id,
      todoId: todoId,
      name: name,
      url: url,
      type: type,
      sizeBytes: sizeBytes,
      createdAt: createdAt,
    );
  }
}
