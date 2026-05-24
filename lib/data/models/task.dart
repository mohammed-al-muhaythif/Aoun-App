enum TaskPriority { high, medium, low }
enum TaskStatus { pending, inProgress, completed, overdue, cancelled }

TaskPriority priorityFromString(String s) =>
    TaskPriority.values.firstWhere((p) => p.name == s);
TaskStatus statusFromString(String s) {
  switch (s) {
    case 'in_progress':
      return TaskStatus.inProgress;
    case 'completed':
      return TaskStatus.completed;
    case 'overdue':
      return TaskStatus.overdue;
    case 'cancelled':
      return TaskStatus.cancelled;
    default:
      return TaskStatus.pending;
  }
}

String statusToString(TaskStatus s) => switch (s) {
      TaskStatus.inProgress => 'in_progress',
      TaskStatus.completed => 'completed',
      TaskStatus.overdue => 'overdue',
      TaskStatus.cancelled => 'cancelled',
      TaskStatus.pending => 'pending',
    };

class Task {
  Task({
    required this.id,
    required this.title,
    this.description,
    required this.priority,
    required this.status,
    this.startDate,
    this.dueDate,
    this.createdBy,
    required this.createdAt,
    this.assigneeUserIds = const [],
    this.assigneeCommitteeIds = const [],
  });

  final String id;
  final String title;
  final String? description;
  final TaskPriority priority;
  final TaskStatus status;
  final DateTime? startDate;
  final DateTime? dueDate;
  final String? createdBy;
  final DateTime createdAt;

  final List<String> assigneeUserIds;
  final List<int> assigneeCommitteeIds;

  factory Task.fromMap(Map<String, dynamic> m) => Task(
        id: m['id'] as String,
        title: m['title'] as String,
        description: m['description'] as String?,
        priority: priorityFromString(m['priority'] as String),
        status: statusFromString(m['status'] as String),
        startDate: m['start_date'] == null
            ? null
            : DateTime.parse(m['start_date'] as String),
        dueDate: m['due_date'] == null
            ? null
            : DateTime.parse(m['due_date'] as String),
        createdBy: m['created_by'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

class TaskComment {
  TaskComment({
    required this.id,
    required this.taskId,
    required this.authorId,
    required this.authorName,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String taskId;
  final String authorId;
  final String authorName;
  final String body;
  final DateTime createdAt;
}

class TaskAttachment {
  TaskAttachment({
    required this.id,
    required this.taskId,
    required this.storagePath,
    required this.fileName,
    required this.fileSize,
    required this.uploadedAt,
    this.uploadedBy,
  });

  final String id;
  final String taskId;
  final String storagePath;
  final String fileName;
  final int fileSize;
  final DateTime uploadedAt;
  final String? uploadedBy;

  factory TaskAttachment.fromMap(Map<String, dynamic> m) => TaskAttachment(
        id: m['id'] as String,
        taskId: m['task_id'] as String,
        storagePath: m['storage_path'] as String,
        fileName: m['file_name'] as String,
        fileSize: (m['file_size'] as num).toInt(),
        uploadedAt: DateTime.parse(m['uploaded_at'] as String),
        uploadedBy: m['uploaded_by'] as String?,
      );
}
