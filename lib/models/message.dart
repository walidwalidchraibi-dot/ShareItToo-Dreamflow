class Message {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final bool isRead;

  Message({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.isRead = false,
  });

  Message copyWith({bool? isRead}) => Message(
        id: id,
        senderId: senderId,
        text: text,
        timestamp: timestamp,
        isRead: isRead ?? this.isRead,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'senderId': senderId,
        'text': text,
        'timestamp': timestamp.toIso8601String(),
        'isRead': isRead,
      };

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'] as String,
        senderId: json['senderId'] as String,
        text: json['text'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        isRead: (json['isRead'] as bool?) ?? false,
      );
}

class MessageThread {
  final String id;
  final String requestId; // Die zugehörige Mietanfrage
  final String itemId; // Der zugehörige Artikel
  final String itemTitle; // Titel des Artikels (für Anzeige)
  final String user1Id; // Mieter
  final String user2Id; // Vermieter
  final List<Message> messages;
  final DateTime createdAt;
  final DateTime? lastMessageAt;

  MessageThread({
    required this.id,
    required this.requestId,
    required this.itemId,
    required this.itemTitle,
    required this.user1Id,
    required this.user2Id,
    required this.messages,
    required this.createdAt,
    this.lastMessageAt,
  });

  MessageThread copyWith({
    List<Message>? messages,
    DateTime? lastMessageAt,
  }) =>
      MessageThread(
        id: id,
        requestId: requestId,
        itemId: itemId,
        itemTitle: itemTitle,
        user1Id: user1Id,
        user2Id: user2Id,
        messages: messages ?? this.messages,
        createdAt: createdAt,
        lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'requestId': requestId,
        'itemId': itemId,
        'itemTitle': itemTitle,
        'user1Id': user1Id,
        'user2Id': user2Id,
        'messages': messages.map((m) => m.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'lastMessageAt': lastMessageAt?.toIso8601String(),
      };

  factory MessageThread.fromJson(Map<String, dynamic> json) {
    final messagesList = (json['messages'] as List?)?.map((e) => Message.fromJson(Map<String, dynamic>.from(e as Map))).toList() ?? <Message>[];
    return MessageThread(
      id: json['id'] as String,
      requestId: json['requestId'] as String,
      itemId: json['itemId'] as String,
      itemTitle: json['itemTitle'] as String,
      user1Id: json['user1Id'] as String,
      user2Id: json['user2Id'] as String,
      messages: messagesList,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastMessageAt: json['lastMessageAt'] != null ? DateTime.parse(json['lastMessageAt'] as String) : null,
    );
  }
}
