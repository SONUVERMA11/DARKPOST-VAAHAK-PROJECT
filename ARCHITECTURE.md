# Darkpost Architecture & Analysis

This document provides a comprehensive breakdown and architectural graph of the **Darkpost** project. You can refer to this graph in any chat to quickly understand the flow of data, state, and services.

## Architecture Graph

```mermaid
graph TD
    %% Main Application Flow
    subgraph UI Layer [UI Layer (Flutter Screens)]
        Splash[SplashScreen<br/>(Boot & Key Gen)]
        Home[HomeScreen<br/>(Node Discovery)]
        Chat[ChatScreen<br/>(Messaging)]
        Identity[IdentityScreen<br/>(Key & Alias Info)]
    end

    %% Services
    subgraph Service Layer [Service Layer (Singletons)]
        EncService[EncryptionService<br/>AES-256 / Keypairs]
        P2P[P2PService<br/>Mesh / Discovery]
    end

    %% Data Models
    subgraph Data Models [Models (models.dart)]
        NodeModel[DarkNode<br/>id, alias, pubKey, signal]
        MsgModel[DarkMessage<br/>payload, status, hops]
    end

    %% Boot Flow
    Splash -->|1. Initializes| EncService
    Splash -->|2. Navigates on Ready| Home

    %% User Interaction Flow
    Home -->|Starts Scan| P2P
    Home -->|Views Identity| Identity
    Home -->|Selects Node| Chat
    Chat -->|Sends Msg| P2P
    
    %% Service Interactions
    P2P -->|Stream<List<DarkNode>>| Home
    P2P -->|Stream<DarkMessage>| Chat
    
    %% Encryption Flow
    Chat -.->|Encrypts/Decrypts| EncService
    Identity -.->|Fetches PubKey/Alias| EncService
    P2P -.->|Simulates Encrypted Incoming| EncService

    %% Models
    P2P -->|Instantiates & Emits| NodeModel
    P2P -->|Instantiates & Emits| MsgModel
    Home -.->|Consumes| NodeModel
    Chat -.->|Consumes| MsgModel

    %% Styling
    classDef ui fill:#0E0E1A,stroke:#00FF88,stroke-width:2px,color:#E8E8F5
    classDef service fill:#161628,stroke:#00C8FF,stroke-width:2px,color:#E8E8F5
    classDef model fill:#161628,stroke:#FFB800,stroke-width:2px,color:#E8E8F5
    
    class Splash,Home,Chat,Identity ui
    class EncService,P2P service
    class NodeModel,MsgModel model
```

## Detailed Component Analysis

### 1. UI Layer (`lib/screens/`)
- **`SplashScreen`**: Boots the app, triggers `EncryptionService` to generate a random private/public keypair on the first launch, and transitions to the Home Screen.
- **`HomeScreen`**: The central hub. It listens to a `Stream<List<DarkNode>>` from the `P2PService` and displays nearby nodes, showing signal strength, alias, and hop count. It includes a radar scanning animation.
- **`ChatScreen`**: Handles the actual messaging UI. It communicates with a selected `DarkNode`. It encrypts outgoing text via `EncryptionService`, sends it through `P2PService`, and decrypts incoming messages via a `Stream<DarkMessage>`. Features an encrypted/decrypted toggle view.
- **`IdentityScreen`**: Displays the user's generated cyber-alias, fingerprint, and full public key. Explains the security premise (device = identity).

### 2. Service Layer (`lib/services/`)
- **`EncryptionService`**: A singleton that acts as the cryptographic heart. It generates a mock RSA/ECC keypair (currently using `sha256` derived public keys) and handles AES-256-CBC encryption for payloads. Generates the cool "cyber" alias names (e.g., "GHOST.NODE.07").
- **`P2PService`**: A singleton mimicking a mesh network. Currently implements a mocked discovery loop (`Timer`) that streams random `DarkNode` entities. It also mocks message delivery (`sendMessage`) and incoming messages (`simulateIncoming`). It provides reactive streams (`nodesStream`, `messageStream`) that the UI listens to. **This is the primary file to modify when migrating to real WiFi Direct/Bluetooth.**

### 3. Data Models (`lib/models/models.dart`)
- **`DarkNode`**: Represents a device on the mesh network. Contains identity properties (`id`, `alias`, `publicKeyHex`), network metrics (`signalStrength`, `hopCount`), and status.
- **`DarkMessage`**: Represents an E2E encrypted message. Contains sender/receiver IDs, the encrypted payload, a decrypted fallback, timestamp, and network metrics (`hopsTraversed`).

### 4. Theme Engine (`lib/theme/app_theme.dart`)
- A robust, heavily stylized "Underground Cipher Aesthetic" using a dark background (`#07070D`), neon green primary (`#00FF88`), and cyan accents (`#00C8FF`). Uses `GoogleFonts.spaceGrotesk` and `GoogleFonts.sourceCodePro` for a terminal/cyberpunk feel. Implements custom decorations like `glowBox` to simulate glowing neon borders.

## Future Path (Phase 2 & 3)
When implementing real hardware connectivity (WiFi Direct or Bluetooth):
1. **Remove Mock Timers** in `P2PService`.
2. **Hook up `nearby_connections` or `wifi_iot`** plugins.
3. Replace the `_simulateNodeDiscovery` array push with actual `onEndpointFound` callbacks.
4. Replace the `sendMessage` delay with real socket/channel writes.
