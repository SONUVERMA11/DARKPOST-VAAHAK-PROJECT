import 'package:uuid/uuid.dart';

enum MessageStatus { sending, delivered, failed }
enum NodeStatus { online, idle, offline }

class DarkNode {
  final String id;
  final String alias;
  final String publicKeyHex;
  final NodeStatus status;
  final DateTime lastSeen;
  final int hopCount;
  final double signalStrength; // 0.0 - 1.0

  const DarkNode({
    required this.id,
    required this.alias,
    required this.publicKeyHex,
    required this.status,
    required this.lastSeen,
    this.hopCount = 0,
    this.signalStrength = 1.0,
  });

  DarkNode copyWith({
    String? id,
    String? alias,
    String? publicKeyHex,
    NodeStatus? status,
    DateTime? lastSeen,
    int? hopCount,
    double? signalStrength,
  }) {
    return DarkNode(
      id: id ?? this.id,
      alias: alias ?? this.alias,
      publicKeyHex: publicKeyHex ?? this.publicKeyHex,
      status: status ?? this.status,
      lastSeen: lastSeen ?? this.lastSeen,
      hopCount: hopCount ?? this.hopCount,
      signalStrength: signalStrength ?? this.signalStrength,
    );
  }

  String get shortId => id.substring(0, 8).toUpperCase();

  factory DarkNode.mock(String alias, {int hop = 0, double signal = 0.8}) {
    return DarkNode(
      id: const Uuid().v4(),
      alias: alias,
      publicKeyHex: _randomHex(32),
      status: NodeStatus.online,
      lastSeen: DateTime.now(),
      hopCount: hop,
      signalStrength: signal,
    );
  }
}

class DarkMessage {
  final String id;
  final String fromId;
  final String toId;
  final String encryptedPayload;
  final String? decryptedText;
  final DateTime timestamp;
  final MessageStatus status;
  final bool isMine;
  final int hopsTraversed;

  const DarkMessage({
    required this.id,
    required this.fromId,
    required this.toId,
    required this.encryptedPayload,
    this.decryptedText,
    required this.timestamp,
    required this.status,
    required this.isMine,
    this.hopsTraversed = 0,
  });

  factory DarkMessage.create({
    required String fromId,
    required String toId,
    required String text,
    required String encrypted,
    bool isMine = true,
  }) {
    return DarkMessage(
      id: const Uuid().v4(),
      fromId: fromId,
      toId: toId,
      encryptedPayload: encrypted,
      decryptedText: text,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
      isMine: isMine,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fromId': fromId,
      'toId': toId,
      'encryptedPayload': encryptedPayload,
      'decryptedText': decryptedText,
      'timestamp': timestamp.toIso8601String(),
      'status': status.index,
      'isMine': isMine,
      'hopsTraversed': hopsTraversed,
    };
  }

  factory DarkMessage.fromJson(Map<String, dynamic> json) {
    return DarkMessage(
      id: json['id'] as String,
      fromId: json['fromId'] as String,
      toId: json['toId'] as String,
      encryptedPayload: json['encryptedPayload'] as String,
      decryptedText: json['decryptedText'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      status: MessageStatus.values[json['status'] as int],
      isMine: json['isMine'] as bool,
      hopsTraversed: json['hopsTraversed'] as int? ?? 0,
    );
  }
}

String _randomHex(int len) {
  const chars = '0123456789abcdef';
  final buf = StringBuffer();
  for (var i = 0; i < len * 2; i++) {
    buf.write(chars[(DateTime.now().microsecond + i * 7) % 16]);
  }
  return buf.toString();
}
