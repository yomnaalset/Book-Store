class ProofOfDelivery {
  final String id;
  final String deliveryTaskId;
  final String signature;
  final String? photo;
  final String? notes;
  final String receiverName;
  final String? receiverRelationship;
  final DateTime timestamp;
  final bool isComplete;

  ProofOfDelivery({
    required this.id,
    required this.deliveryTaskId,
    required this.signature,
    this.photo,
    this.notes,
    required this.receiverName,
    this.receiverRelationship,
    required this.timestamp,
    this.isComplete = false,
  });

  factory ProofOfDelivery.fromJson(Map<String, dynamic> json) {
    return ProofOfDelivery(
      id: json['id']?.toString() ?? '',
      deliveryTaskId:
          json['deliveryTaskId']?.toString() ??
          json['delivery_task_id']?.toString() ??
          '',
      signature: json['signature'] ?? '',
      photo: json['photo'],
      notes: json['notes'],
      receiverName: json['receiverName'] ?? json['receiver_name'] ?? '',
      receiverRelationship:
          json['receiverRelationship'] ?? json['receiver_relationship'],
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      isComplete: json['isComplete'] ?? json['is_complete'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deliveryTaskId': deliveryTaskId,
      'signature': signature,
      'photo': photo,
      'notes': notes,
      'receiverName': receiverName,
      'receiverRelationship': receiverRelationship,
      'timestamp': timestamp.toIso8601String(),
      'isComplete': isComplete,
    };
  }

  ProofOfDelivery copyWith({
    String? id,
    String? deliveryTaskId,
    String? signature,
    String? photo,
    String? notes,
    String? receiverName,
    String? receiverRelationship,
    DateTime? timestamp,
    bool? isComplete,
  }) {
    return ProofOfDelivery(
      id: id ?? this.id,
      deliveryTaskId: deliveryTaskId ?? this.deliveryTaskId,
      signature: signature ?? this.signature,
      photo: photo ?? this.photo,
      notes: notes ?? this.notes,
      receiverName: receiverName ?? this.receiverName,
      receiverRelationship: receiverRelationship ?? this.receiverRelationship,
      timestamp: timestamp ?? this.timestamp,
      isComplete: isComplete ?? this.isComplete,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ProofOfDelivery &&
        other.id == id &&
        other.deliveryTaskId == deliveryTaskId &&
        other.signature == signature &&
        other.photo == photo &&
        other.notes == notes &&
        other.receiverName == receiverName &&
        other.receiverRelationship == receiverRelationship &&
        other.timestamp == timestamp &&
        other.isComplete == isComplete;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        deliveryTaskId.hashCode ^
        signature.hashCode ^
        photo.hashCode ^
        notes.hashCode ^
        receiverName.hashCode ^
        receiverRelationship.hashCode ^
        timestamp.hashCode ^
        isComplete.hashCode;
  }
}
