enum TodoAttachmentType {
  image,
  pdf,
  voice,
  file;

  String get jsonKey => name;

  static TodoAttachmentType fromJson(String? value) => switch (value) {
        'image' => TodoAttachmentType.image,
        'pdf' => TodoAttachmentType.pdf,
        'voice' => TodoAttachmentType.voice,
        'file' => TodoAttachmentType.file,
        _ => TodoAttachmentType.file,
      };
}

class TodoAttachment {
  const TodoAttachment({
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

  TodoAttachment copyWith({
    String? name,
    String? url,
    TodoAttachmentType? type,
    int? sizeBytes,
  }) {
    return TodoAttachment(
      id: id,
      todoId: todoId,
      name: name ?? this.name,
      url: url ?? this.url,
      type: type ?? this.type,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      createdAt: createdAt,
    );
  }
}
