class AppNotification {
  AppNotification({
    required this.id,
    required this.recipientId,
    required this.title,
    required this.body,
    required this.type,
    this.relatedId,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String recipientId;
  final String title;
  final String body;
  final String type;
  final String? relatedId;
  final bool isRead;
  final DateTime createdAt;

  factory AppNotification.fromMap(Map<String, dynamic> m) => AppNotification(
        id: m['id'] as String,
        recipientId: m['recipient_id'] as String,
        title: m['title'] as String,
        body: m['body'] as String,
        type: m['type'] as String,
        relatedId: m['related_id'] as String?,
        isRead: m['is_read'] as bool,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}
