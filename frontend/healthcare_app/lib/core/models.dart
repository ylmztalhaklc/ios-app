class AppUser {
  final int id;
  final String fullName;
  final String email;
  final String role;
  final bool isActive;

  AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.isActive,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as int,
      fullName: json['full_name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      isActive: json['is_active'] as bool,
    );
  }
}

class TaskTemplate {
  final int id;
  final String title;
  final String? description;
  final String? defaultTime;
  final String taskType;
  final int createdById;
  final bool isActive;
  final DateTime createdAt;

  TaskTemplate({
    required this.id,
    required this.title,
    this.description,
    this.defaultTime,
    this.taskType = 'normal',
    required this.createdById,
    required this.isActive,
    required this.createdAt,
  });

  factory TaskTemplate.fromJson(Map<String, dynamic> json) {
    return TaskTemplate(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      defaultTime: json['default_time'] as String?,
      taskType: json['task_type'] as String? ?? 'normal',
      createdById: json['created_by_id'] as int,
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class TaskInstance {
  final int id;
  final int templateId;
  final String title;
  final String? description;
  final String status;
  final DateTime scheduledFor;
  final String? problemMessage;
  final String? problemSeverity;
  final String? resolutionNote;
  final String? completionPhotoUrl;
  final int? rating;
  final String? reviewNote;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int createdById;
  final int assignedToId;

  TaskInstance({
    required this.id,
    required this.templateId,
    required this.title,
    this.description,
    required this.status,
    required this.scheduledFor,
    this.problemMessage,
    this.problemSeverity,
    this.resolutionNote,
    this.completionPhotoUrl,
    this.rating,
    this.reviewNote,
    required this.createdAt,
    required this.updatedAt,
    required this.createdById,
    required this.assignedToId,
  });

  factory TaskInstance.fromJson(Map<String, dynamic> json) {
    return TaskInstance(
      id: json['id'] as int,
      templateId: json['template_id'] as int,
      title: (json['title'] as String?) ?? 'İsimsiz Görev',
      description: json['description'] as String?,
      status: json['status'] as String,
      scheduledFor: DateTime.parse(json['scheduled_for'] as String),
      problemMessage: json['problem_message'] as String?,
      problemSeverity: json['problem_severity'] as String?,
      resolutionNote: json['resolution_note'] as String?,
      completionPhotoUrl: json['completion_photo_url'] as String?,
      rating: json['rating'] as int?,
      reviewNote: json['review_note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      createdById: json['created_by_id'] as int,
      assignedToId: json['assigned_to_id'] as int,
    );
  }
}

class NotificationModel {
  final int id;
  final int userId;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      message: json['message'] as String,
      isRead: json['is_read'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class MessageAttachment {
  final int id;
  final int messageId;
  final String fileType;
  final String filePath;
  final String fileName;
  final int? fileSize;
  final DateTime uploadedAt;

  MessageAttachment({
    required this.id,
    required this.messageId,
    required this.fileType,
    required this.filePath,
    required this.fileName,
    this.fileSize,
    required this.uploadedAt,
  });

  factory MessageAttachment.fromJson(Map<String, dynamic> json) {
    return MessageAttachment(
      id: json['id'] as int,
      messageId: json['message_id'] as int,
      fileType: json['file_type'] as String,
      filePath: json['file_path'] as String,
      fileName: json['file_name'] as String,
      fileSize: json['file_size'] as int?,
      uploadedAt: DateTime.parse(json['uploaded_at'] as String),
    );
  }
}

class Message {
  final int id;
  final int senderId;
  final int receiverId;
  final String? content;
  final DateTime sentAt;
  final bool isEdited;
  final DateTime? editedAt;
  final bool isDeleted;
  final bool isRead;
  final DateTime? readAt;
  final List<MessageAttachment> attachments;

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    this.content,
    required this.sentAt,
    required this.isEdited,
    this.editedAt,
    required this.isDeleted,
    required this.isRead,
    this.readAt,
    this.attachments = const [],
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as int,
      senderId: json['sender_id'] as int,
      receiverId: json['receiver_id'] as int,
      content: json['content'] as String?,
      sentAt: DateTime.parse(json['sent_at'] as String),
      isEdited: json['is_edited'] as bool,
      editedAt: json['edited_at'] != null
          ? DateTime.parse(json['edited_at'] as String)
          : null,
      isDeleted: json['is_deleted'] as bool,
      isRead: json['is_read'] as bool,
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
      attachments: (json['attachments'] as List<dynamic>?)
              ?.map((e) => MessageAttachment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class ConversationPreview {
  final int otherUserId;
  final String otherUserName;
  final String otherUserRole;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;

  ConversationPreview({
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserRole,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
  });

  factory ConversationPreview.fromJson(Map<String, dynamic> json) {
    return ConversationPreview(
      otherUserId: json['other_user_id'] as int,
      otherUserName: json['other_user_name'] as String,
      otherUserRole: json['other_user_role'] as String,
      lastMessage: json['last_message'] as String?,
      lastMessageTime: json['last_message_time'] != null
          ? DateTime.parse(json['last_message_time'] as String)
          : null,
      unreadCount: json['unread_count'] as int? ?? 0,
    );
  }
}
