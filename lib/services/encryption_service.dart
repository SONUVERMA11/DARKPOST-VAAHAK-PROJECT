import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:pointycastle/export.dart' as pc;
import 'package:hive_flutter/hive_flutter.dart';

class EncryptionService {
  static final EncryptionService _instance = EncryptionService._();
  factory EncryptionService() => _instance;
  EncryptionService._();

  late pc.RSAPrivateKey _privateKey;
  late pc.RSAPublicKey _publicKey;
  late String _publicKeyHex;

  String get publicKeyHex => _publicKeyHex;
  String get shortFingerprint => _publicKeyHex.substring(0, 16).toUpperCase();

  // Load from Hive or Generate true RSA-2048 keypair on first launch
  Future<void> initialize() async {
    final box = Hive.box('identityBox');
    final pubHex = box.get('publicKeyHex');
    final privStr = box.get('privateKeyParams');

    if (pubHex != null && privStr != null) {
      // 1. Load existing keypair
      _publicKeyHex = pubHex;
      _publicKey = _parsePublicKey(_publicKeyHex);
      
      final parts = privStr.split('|');
      _privateKey = pc.RSAPrivateKey(
        BigInt.parse(parts[0], radix: 16),
        BigInt.parse(parts[1], radix: 16),
        BigInt.parse(parts[2], radix: 16),
        BigInt.parse(parts[3], radix: 16),
      );
    } else {
      // 2. Generate RSA Keypair
      final secureRandom = pc.FortunaRandom();
      final seedSource = Random.secure();
      final seeds = Uint8List(32);
      for (int i = 0; i < 32; i++) {
        seeds[i] = seedSource.nextInt(256);
      }
      secureRandom.seed(pc.KeyParameter(seeds));

      final keyGen = pc.RSAKeyGenerator()
        ..init(pc.ParametersWithRandom(
            pc.RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
            secureRandom));

      final pair = keyGen.generateKeyPair();
      _publicKey = pair.publicKey as pc.RSAPublicKey;
      _privateKey = pair.privateKey as pc.RSAPrivateKey;

      // Serialize Public Key (modulus|exponent)
      _publicKeyHex = '${_publicKey.modulus!.toRadixString(16)}|${_publicKey.exponent!.toRadixString(16)}';
      
      // Serialize Private Key (modulus|privateExponent|p|q)
      final privParams = '${_privateKey.modulus!.toRadixString(16)}|${_privateKey.privateExponent!.toRadixString(16)}|${_privateKey.p!.toRadixString(16)}|${_privateKey.q!.toRadixString(16)}';

      // Save to Hive
      await box.put('publicKeyHex', _publicKeyHex);
      await box.put('privateKeyParams', privParams);
    }
  }

  // Parse Public Key from Hex
  pc.RSAPublicKey _parsePublicKey(String hex) {
    final parts = hex.split('|');
    return pc.RSAPublicKey(
      BigInt.parse(parts[0], radix: 16),
      BigInt.parse(parts[1], radix: 16),
    );
  }

  // Hybrid Encryption: Encrypt message for a specific target node
  String encryptFor(String plaintext, String targetPublicKeyHex) {
    if (targetPublicKeyHex == 'PENDING_EXCHANGE') {
      throw Exception('Target public key not yet exchanged');
    }

    final targetPub = _parsePublicKey(targetPublicKeyHex);

    // 1. Generate a random AES session key for this specific message
    final aesKey = enc.Key.fromSecureRandom(32);
    final iv = enc.IV.fromSecureRandom(16);

    // 2. Encrypt the payload with AES
    final aesEncrypter = enc.Encrypter(enc.AES(aesKey, mode: enc.AESMode.cbc));
    final encryptedPayload = aesEncrypter.encrypt(plaintext, iv: iv);

    // 3. Encrypt the AES key with the target's RSA Public Key
    final rsaEncrypter = enc.Encrypter(enc.RSA(publicKey: targetPub));
    final encryptedAesKey = rsaEncrypter.encryptBytes(aesKey.bytes);

    // 4. Combine into a hybrid payload
    final hybridPayload = {
      'encKey': encryptedAesKey.base64,
      'iv': iv.base64,
      'ct': encryptedPayload.base64,
      'ts': DateTime.now().millisecondsSinceEpoch,
    };

    return base64.encode(utf8.encode(jsonEncode(hybridPayload)));
  }

  // Hybrid Decryption: Decrypt incoming message
  String? decryptFrom(String hybridCiphertext) {
    try {
      final raw = utf8.decode(base64.decode(hybridCiphertext));
      final payload = jsonDecode(raw) as Map<String, dynamic>;

      final encryptedAesKey = enc.Encrypted.fromBase64(payload['encKey']);
      final iv = enc.IV.fromBase64(payload['iv']);
      final ct = payload['ct'];

      // 1. Decrypt the AES key using our RSA Private Key
      final rsaEncrypter = enc.Encrypter(enc.RSA(privateKey: _privateKey));
      final decryptedAesKeyBytes = rsaEncrypter.decryptBytes(encryptedAesKey);
      final aesKey = enc.Key(Uint8List.fromList(decryptedAesKeyBytes));

      // 2. Decrypt the payload using the unwrapped AES key
      final aesEncrypter = enc.Encrypter(enc.AES(aesKey, mode: enc.AESMode.cbc));
      return aesEncrypter.decrypt64(ct, iv: iv);
    } catch (e) {
      return null;
    }
  }

  // Generate node alias from public key
  String generateAlias() {
    const adjectives = [
      'DARK', 'GHOST', 'ECHO', 'SHADOW', 'CIPHER', 'RELAY',
      'STEALTH', 'VOID', 'NEON', 'PULSE'
    ];
    const nouns = [
      'NODE', 'MULE', 'RELAY', 'GATE', 'BRIDGE', 'MESH',
      'LINK', 'DROP', 'POST', 'HOP'
    ];
    final hash = sha256.convert(utf8.encode(_publicKeyHex)).bytes;
    final adj = adjectives[hash[0] % adjectives.length];
    final noun = nouns[hash[1] % nouns.length];
    final num = (hash[2] % 99 + 1).toString().padLeft(2, '0');
    return '$adj.$noun.$num';
  }
}
