import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/models.dart';
import '../services/encryption_service.dart';

class P2PService {
  static final P2PService _instance = P2PService._();
  factory P2PService() => _instance;
  P2PService._();

  final _enc = EncryptionService();
  final _nodesController = StreamController<List<DarkNode>>.broadcast();
  final _messageController = StreamController<DarkMessage>.broadcast();

  Stream<List<DarkNode>> get nodesStream => _nodesController.stream;
  Stream<DarkMessage> get messageStream => _messageController.stream;

  final Map<String, DarkNode> _discoveredNodes = {};
  bool _isScanning = false;

  List<DarkNode> get nodes => List.unmodifiable(_discoveredNodes.values);
  bool get isScanning => _isScanning;

  final Strategy _strategy = Strategy.P2P_CLUSTER;

  // Start scanning for nearby nodes (WiFi Direct / BT)
  Future<void> startScan() async {
    if (_isScanning) return;
    
    // Request necessary hardware permissions
    await [
      Permission.bluetooth,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
      Permission.nearbyWifiDevices,
    ].request();

    _isScanning = true;
    final alias = _enc.generateAlias();

    try {
      // 1. Start Advertising our presence
      await Nearby().startAdvertising(
        alias,
        _strategy,
        onConnectionInitiated: (id, info) async {
          // Auto-accept connection for seamless mesh
          await Nearby().acceptConnection(
            id,
            onPayLoadRecieved: (endId, payload) {
              if (payload.type == PayloadType.BYTES) {
                _handleIncomingBytes(endId, payload.bytes!);
              }
            },
            onPayloadTransferUpdate: (endId, payloadTransferUpdate) {},
          );
        },
        onConnectionResult: (id, status) {
          if (status == Status.CONNECTED) {
            // Send our public key to the newly connected node
            final handshake = jsonEncode({'type': 'handshake', 'pubKey': _enc.publicKeyHex});
            Nearby().sendBytesPayload(id, Uint8List.fromList(utf8.encode(handshake)));
          } else {
            _removeNode(id);
          }
        },
        onDisconnected: (id) => _removeNode(id),
      );

      // 2. Start Discovery for other nodes
      await Nearby().startDiscovery(
        alias,
        _strategy,
        onEndpointFound: (id, name, serviceId) {
          if (!_discoveredNodes.containsKey(id)) {
            // Add to UI as an available node
            final node = DarkNode(
              id: id,
              alias: name,
              publicKeyHex: 'PENDING_EXCHANGE',
              status: NodeStatus.online,
              lastSeen: DateTime.now(),
              signalStrength: 0.9,
            );
            _discoveredNodes[id] = node;
            _nodesController.add(nodes);

            // Initiate connection automatically
            Nearby().requestConnection(
              alias,
              id,
              onConnectionInitiated: (id, info) async {
                await Nearby().acceptConnection(
                  id,
                  onPayLoadRecieved: (endId, payload) {
                    if (payload.type == PayloadType.BYTES) {
                      _handleIncomingBytes(endId, payload.bytes!);
                    }
                  },
                  onPayloadTransferUpdate: (endId, payloadTransferUpdate) {},
                );
              },
              onConnectionResult: (id, status) {
                if (status == Status.CONNECTED) {
                  // Send our public key
                  final handshake = jsonEncode({'type': 'handshake', 'pubKey': _enc.publicKeyHex});
                  Nearby().sendBytesPayload(id, Uint8List.fromList(utf8.encode(handshake)));
                } else {
                  _removeNode(id);
                }
              },
              onDisconnected: (id) => _removeNode(id),
            );
          }
        },
        onEndpointLost: (id) => _removeNode(id),
      );
    } catch (e) {
      _isScanning = false;
    }
  }

  void _removeNode(String? id) {
    if (id == null) return;
    _discoveredNodes.remove(id);
    _nodesController.add(nodes);
  }

  void _handleIncomingBytes(String endpointId, Uint8List bytes) {
    try {
      final jsonStr = utf8.decode(bytes);
      final map = jsonDecode(jsonStr);

      if (map['type'] == 'handshake') {
        if (_discoveredNodes.containsKey(endpointId)) {
          _discoveredNodes[endpointId] = _discoveredNodes[endpointId]!.copyWith(publicKeyHex: map['pubKey']);
          _nodesController.add(nodes);
        }
        return;
      }
      
      final encryptedPayload = map['encrypted'] as String;
      final decrypted = _enc.decryptFrom(encryptedPayload);

      if (decrypted == null) return; // Fail gracefully if unable to decrypt

      
      final msg = DarkMessage(
        id: map['id'] ?? DateTime.now().toIso8601String(),
        fromId: endpointId,
        toId: 'self',
        encryptedPayload: encryptedPayload,
        decryptedText: decrypted,
        timestamp: DateTime.now(),
        status: MessageStatus.delivered,
        isMine: false,
        hopsTraversed: map['hops'] ?? 1,
      );
      
      final box = Hive.box('messagesBox');
      box.put(msg.id, msg.toJson());

      _messageController.add(msg);
    } catch (e) {
      // Failed to parse or decrypt
    }
  }

  void stopScan() {
    _isScanning = false;
    Nearby().stopAdvertising();
    Nearby().stopDiscovery();
    Nearby().stopAllEndpoints();
    _discoveredNodes.clear();
    _nodesController.add([]);
  }

  // Send encrypted message to a node
  Future<bool> sendMessage(DarkMessage message) async {
    try {
      final endpointId = message.toId;
      if (!_discoveredNodes.containsKey(endpointId)) return false;
      
      final payloadMap = {
        'id': message.id,
        'encrypted': message.encryptedPayload,
        'hops': message.hopsTraversed,
      };
      
      final bytes = utf8.encode(jsonEncode(payloadMap));
      await Nearby().sendBytesPayload(endpointId, Uint8List.fromList(bytes));
      
      final box = Hive.box('messagesBox');
      box.put(message.id, message.toJson());

      return true;
    } catch (e) {
      return false;
    }
  }

  // Fallback for legacy UI tests if needed
  void simulateIncoming(String fromId, String fromAlias) {}

  void dispose() {
    stopScan();
    _nodesController.close();
    _messageController.close();
  }
}
