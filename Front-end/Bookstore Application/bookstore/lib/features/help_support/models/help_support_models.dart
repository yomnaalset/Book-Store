class FAQ {
  final int id;
  final String question;
  final String answer;
  final String category;
  final int order;
  final DateTime createdAt;
  final DateTime updatedAt;

  FAQ({
    required this.id,
    required this.question,
    required this.answer,
    required this.category,
    required this.order,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FAQ.fromJson(Map<String, dynamic> json) {
    return FAQ(
      id: json['id'],
      question: json['question'],
      answer: json['answer'],
      category: json['category'],
      order: json['order'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'answer': answer,
      'category': category,
      'order': order,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class UserGuide {
  final int id;
  final String title;
  final String content;
  final String section;
  final int order;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserGuide({
    required this.id,
    required this.title,
    required this.content,
    required this.section,
    required this.order,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserGuide.fromJson(Map<String, dynamic> json) {
    return UserGuide(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      section: json['section'],
      order: json['order'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'section': section,
      'order': order,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class TroubleshootingGuide {
  final int id;
  final String title;
  final String description;
  final String solution;
  final String category;
  final int order;
  final DateTime createdAt;
  final DateTime updatedAt;

  TroubleshootingGuide({
    required this.id,
    required this.title,
    required this.description,
    required this.solution,
    required this.category,
    required this.order,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TroubleshootingGuide.fromJson(Map<String, dynamic> json) {
    return TroubleshootingGuide(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      solution: json['solution'],
      category: json['category'],
      order: json['order'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'solution': solution,
      'category': category,
      'order': order,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class SupportContact {
  final int id;
  final String contactType;
  final String contactTypeDisplay;
  final String title;
  final String description;
  final String contactInfo;
  final bool isAvailable;
  final String availableHours;
  final bool isAdminOnly;
  final int order;
  final DateTime createdAt;
  final DateTime updatedAt;

  SupportContact({
    required this.id,
    required this.contactType,
    required this.contactTypeDisplay,
    required this.title,
    required this.description,
    required this.contactInfo,
    required this.isAvailable,
    required this.availableHours,
    required this.isAdminOnly,
    required this.order,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SupportContact.fromJson(Map<String, dynamic> json) {
    return SupportContact(
      id: json['id'],
      contactType: json['contact_type'],
      contactTypeDisplay: json['contact_type_display'],
      title: json['title'],
      description: json['description'],
      contactInfo: json['contact_info'],
      isAvailable: json['is_available'],
      availableHours: json['available_hours'] ?? '',
      isAdminOnly: json['is_admin_only'],
      order: json['order'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'contact_type': contactType,
      'contact_type_display': contactTypeDisplay,
      'title': title,
      'description': description,
      'contact_info': contactInfo,
      'is_available': isAvailable,
      'available_hours': availableHours,
      'is_admin_only': isAdminOnly,
      'order': order,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class HelpSupportData {
  final List<FAQ> faqs;
  final List<UserGuide> userGuides;
  final List<TroubleshootingGuide> troubleshootingGuides;
  final List<SupportContact> supportContacts;

  HelpSupportData({
    required this.faqs,
    required this.userGuides,
    required this.troubleshootingGuides,
    required this.supportContacts,
  });

  factory HelpSupportData.fromJson(Map<String, dynamic> json) {
    return HelpSupportData(
      faqs: (json['faqs'] as List? ?? [])
          .map((item) => FAQ.fromJson(item))
          .toList(),
      userGuides: (json['user_guides'] as List? ?? [])
          .map((item) => UserGuide.fromJson(item))
          .toList(),
      troubleshootingGuides: (json['troubleshooting_guides'] as List? ?? [])
          .map((item) => TroubleshootingGuide.fromJson(item))
          .toList(),
      supportContacts: (json['support_contacts'] as List? ?? [])
          .map((item) => SupportContact.fromJson(item))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'faqs': faqs.map((item) => item.toJson()).toList(),
      'user_guides': userGuides.map((item) => item.toJson()).toList(),
      'troubleshooting_guides': troubleshootingGuides
          .map((item) => item.toJson())
          .toList(),
      'support_contacts': supportContacts.map((item) => item.toJson()).toList(),
    };
  }
}
