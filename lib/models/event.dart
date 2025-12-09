class Event {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final String? userId;
  final String? houseId;
  final DateTime? createdAt;

  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    this.userId,
    this.houseId,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date.toIso8601String(),
      'userId': userId,
      'houseId': houseId,
      'createdAt': createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }

  factory Event.fromMap(Map<String, dynamic> map) {
    return Event(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      date: DateTime.parse(map['date'] ?? DateTime.now().toIso8601String()),
      userId: map['userId'],
      houseId: map['houseId'],
      createdAt: map['createdAt'] != null 
          ? DateTime.parse(map['createdAt'])
          : null,
    );
  }
}