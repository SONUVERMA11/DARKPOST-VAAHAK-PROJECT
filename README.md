# DARKPOST — Build Guide

## Offline · Encrypted · P2P Messenger
### No Internet · No SIM · No Identity

---

## Prerequisites

Install these on your machine:

1. **Flutter SDK** (3.x)
   ```
   https://docs.flutter.dev/get-started/install
   ```

2. **Android Studio** + Android SDK (API 21+)
   ```
   https://developer.android.com/studio
   ```

3. **Java 17** (included with Android Studio)

---

## Setup Steps

### 1. Clone / extract this project
```bash
cd darkpost
```

### 2. Get dependencies
```bash
flutter pub get
```

### 3. Add ShareTech Mono font
Download from Google Fonts:
```
https://fonts.google.com/specimen/Share+Tech+Mono
```
Place `ShareTechMono-Regular.ttf` in `assets/fonts/`

### 4. Run on connected Android device
```bash
# Check device connected
adb devices

# Run debug
flutter run

# OR build release APK
flutter build apk --release
```

### 5. Find your APK
```
build/app/outputs/flutter-apk/app-release.apk
```

Install on phone:
```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

---

## Features in MVP

| Feature | Status |
|---------|--------|
| AES-256 message encryption | ✅ |
| Cryptographic node identity | ✅ |
| Mesh node discovery UI | ✅ (mock) |
| Encrypted chat interface | ✅ |
| Toggle encrypted/decrypted view | ✅ |
| Multi-hop relay display | ✅ |
| Dark minimalist UI | ✅ |
| WiFi Direct (real hardware) | 🔜 Phase 2 |
| Bluetooth mesh | 🔜 Phase 2 |
| UPI micro-payments | 🔜 Phase 3 |

---

## Phase 2 — Real WiFi Direct

Add this plugin to pubspec.yaml:
```yaml
wifi_iot: ^0.3.19+1
nearby_connections: ^3.3.0
```

Replace `P2PService._simulateNodeDiscovery()` with:
```dart
import 'package:nearby_connections/nearby_connections.dart';

await Nearby().startAdvertising(
  myAlias,
  Strategy.P2P_CLUSTER,
  onConnectionInitiated: _onConnection,
  onConnectionResult: _onResult,
  onDisconnected: _onDisconnect,
);

await Nearby().startDiscovery(
  myAlias,
  Strategy.P2P_CLUSTER,
  onEndpointFound: (id, name, serviceId) {
    _discoveredNodes.add(DarkNode(...));
  },
  onEndpointLost: (id) { ... },
);
```

---

## Architecture Overview

```
┌─────────────────────────────────┐
│         DARKPOST APP            │
├─────────────────────────────────┤
│  UI Layer (Flutter/Dart)        │
│  • SplashScreen                 │
│  • HomeScreen (node discovery)  │
│  • ChatScreen (messaging)       │
│  • IdentityScreen (keypair)     │
├─────────────────────────────────┤
│  EncryptionService              │
│  • AES-256-CBC encryption       │
│  • RSA keypair generation       │
│  • Message signing              │
├─────────────────────────────────┤
│  P2PService                     │
│  • WiFi Direct (Phase 2)        │
│  • Bluetooth mesh (Phase 2)     │
│  • DTN routing (Phase 3)        │
├─────────────────────────────────┤
│  Transport Layer                │
│  • WiFi Direct API              │
│  • Nearby Connections API       │
│  • LoRa (future hardware)       │
└─────────────────────────────────┘
```

---

## Color Palette
```
Background  #07070D
Surface     #0E0E1A
Primary     #00FF88  (green)
Accent      #00C8FF  (cyan)
Danger      #FF3B5C  (red)
```

---

Built for India. No internet. No SIM. No surveillance.
```
DARKPOST v1.0 — VAAHAK PROJECT
```
