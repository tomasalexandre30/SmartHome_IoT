<div align="center">

# SmartSpace

![Flutter](https://img.shields.io/badge/Flutter-3.19+-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.9-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![ESP32](https://img.shields.io/badge/ESP32-Firmware-E7352C?style=for-the-badge&logo=espressif&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-Cloud-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)

### Sistemas de IoT e Móveis (2025/26) — NOVA School of Science & Technology

*A **smart space management system** that automatically adapts the physical environment of each room to the presence and preferences of its users.*

</div>

---

## About the Project

**SmartSpace** is an intelligent indoor space management system that combines **Bluetooth Low Energy (BLE)** for indoor localisation, **ESP32 IoT devices** with sensors and actuators, and a **Flutter Android application**, all coordinated via **Firebase**.

The system detects which zone each user is in, adapts the environment automatically based on sensor data and personal preferences, and resolves conflicts between multiple users through a real-time voting system.

> 📄 For a comprehensive and in-depth explanation of the system architecture, implementation details, experiments and results, read the full project report:
>
> **[Access the Full Project Report](report/SmartSpace_Report.pdf)**

### Key Highlights

- **BLE-based indoor localisation** with RSSI smoothing via moving average
- **Real-time environmental automation** driven by LDR and DHT22 sensors
- **Multi-user conflict resolution** through collaborative voting with counter-proposals
- **N-to-M architecture** — multiple phones communicate with multiple ESP32 devices via Firebase
- **Interactive admin map** with live zone occupancy, ESP32 pulse animation and user avatars
- **In-app notifications** for zone entry/exit with role-based filtering
- **Full offline resilience** — pending command queue on the app side, autonomous mode on ESP32

---

## Features

| Feature | Description |
|---------|-------------|
| **BLE Zone Detection** | Automatically detects the user's current zone based on beacon RSSI |
| **Environmental Automation** | LDR controls lighting; DHT22 triggers buzzer alerts for temperature and humidity |
| **Voting System** | Multi-user conflict resolution with majority vote, counter-proposals and timeout |
| **Adaptive Lighting (AUTO mode)** | Blends all present users' preferences, modulated by ambient light |
| **Admin Dashboard** | Global view of all zones, sensors, users and ESP32 connectivity |
| **Interactive Zone Map** | Real-time floor plan with occupancy, ESP32 status and user avatars |
| **User Preferences** | Per-zone lighting intensity, RGB colour, temperature target and do-not-disturb |
| **In-App Notifications** | Animated banners for zone entry/exit, filtered by user role |
| **Event Logs** | Full audit trail of all system events stored in Firestore |
| **Energy Monitoring** | Per-zone energy consumption estimation based on actuator uptime |
| **Offline Resilience** | Pending command queue + ESP32 autonomous mode on connection loss |

---

## System Architecture

The SmartSpace architecture follows a **three-layer model** with asynchronous communication mediated by Firebase:

```
[Android App]  ←──  BLE Scan  ──→  [BLE Beacons × 3]
      ↕
[Firebase RTDB / Firestore / Auth]
      ↕
[ESP32 + Sensors/Actuators]  ←──  WiFi  ──→  Firebase
```

- **N mobile devices** communicate with **M BLE beacons** for localisation
- **P ESP32 devices** communicate with Firebase for control and state sync
- No direct communication between phones and ESP32 — Firebase acts as the central broker

---

## Mobile Application

The app was built in **Flutter/Dart** for Android, following the **Provider + ChangeNotifier** pattern with clear separation between UI, business logic and services.

### Admin Interface

<p align="center">
  <img src="lib/assets/admin_dashboard.png" width="180">
  <img src="lib/assets/admin_map.png" width="180">
  <img src="lib/assets/admin_log.png" width="180">
  <img src="lib/assets/admin_settings.png" width="180">
</p>

The admin dashboard provides a global view of all zones, an interactive floor plan map, full event history and system configuration.

### User Interface

<p align="center">
  <img src="lib/assets/login_registo.png" width="180">
  <img src="lib/assets/user_dashboard.png" width="180">
  <img src="lib/assets/user_zones.png" width="180">
  <img src="lib/assets/user_preferences.png" width="180">
</p>

Users see their current zone, control lighting and other actuators, manage personal preferences, and participate in voting when sharing a zone with others.

### Voting System

<p align="center">
  <img src="lib/assets/user_conflict.png" width="180">
</p>

When multiple users are in the same zone, any manual command triggers a 30-second collaborative vote. Results are applied immediately once all votes are in, with counter-proposals averaged for continuous parameters like intensity and colour.

---

## IoT — ESP32

Each ESP32 unit is responsible for local sensing, automation and actuation. It communicates with Firebase over WiFi using the **FirebaseESP32 by Mobizt** library.

### Sensors & Actuators

| Component | Type | GPIO | Function |
|-----------|------|------|----------|
| DHT22 | Sensor | 32 | Temperature and humidity measurement |
| LDR | Sensor | 34 | Ambient light measurement |
| RGB LED (lighting) | Actuator | 25 / 26 / 27 | Adaptive zone illumination |
| RGB LED (status) | Actuator | 21 / 19 / 18 | Zone occupancy indicator (green/red) |
| Passive Buzzer | Actuator | 14 | Environmental alert sounds |

### Circuit

<p align="center">
  <img src="lib/assets/Circuito_iot.png" width="500">
</p>

### Automation Logic

The firmware uses **transition guards** to write to Firebase only on state changes, avoiding redundant writes. Temperature and humidity alerts use **independent guards** with an AND condition — the buzzer only silences when both alerts have cleared simultaneously.

---

## BLE Beacons

Three physical BLE beacons are placed in the monitored zones. The mobile app performs continuous passive scanning and assigns each user to the zone of the beacon with the highest smoothed RSSI.

| Zone | Room | Beacon Name | MAC |
|------|------|-------------|-----|
| A | Living Room | R24120458 | 51:00:24:12:01:CA |
| B | Bedroom | R24120483 | 51:00:24:12:01:E3 |
| C | Office | R24120434 | 51:00:24:12:01:B2 |

---

## Firebase Structure

```
smartspace/
  zones/{zoneId}/       ← full zone state: sensors, actuators, occupancy, poll, automations
  commands/{zoneId}/    ← commands written by app, read by ESP32 via stream
  users/{uid}/          ← online status and current zone of each user
```

- **Firestore** — user profiles, per-zone preferences, event logs
- **Firebase Auth** — identity management for users and ESP32 service account

---

## Setup & Installation

### Flutter App

```bash
# Clone the repository
git clone https://github.com/tomasalexandre30/SmartHome_IoT.git

# Install dependencies
flutter pub get

# Run the app
flutter run
```

> Requires Flutter SDK 3.19+, Android Studio, and a physical Android device with Bluetooth enabled.

### ESP32 Firmware

1. Open the firmware folder in **Arduino IDE**
2. Install the required libraries:
    - FirebaseESP32 by Mobizt
    - ArduinoJson
    - DHT sensor library by Adafruit
    - Adafruit Unified Sensor
3. Configure your WiFi and Firebase credentials in the firmware constants
4. Upload to the ESP32

> Before powering the ESP32, ensure the `commands/zone_a` node exists in Firebase RTDB with all required fields (`lightOn`, `lightIntensity`, `lightR`, `lightG`, `lightB`, `buzzerOn`).

---

## Technologies

| Technology | Purpose |
|------------|---------|
| **Flutter / Dart** | Mobile application (Android) |
| **Firebase RTDB** | Real-time state sync between app and ESP32 |
| **Firebase Firestore** | Persistent storage: profiles, preferences, logs |
| **Firebase Auth** | User identity and role management |
| **ESP32 + Arduino IDE** | IoT firmware: sensing, automation, actuation |
| **BLE iBeacons** | Indoor localisation via RSSI |
| **FirebaseESP32 (Mobizt)** | Firebase communication from ESP32 |

---

## Authors

This project was developed as part of the **Sistemas de IoT e Móveis** course in the **MSc in Computer Engineering** program at **NOVA School of Science and Technology**.

| Student | Number |
|---------|--------|
| Tomás Alexandre | 73213 |
| Nicolae Iachimovschi | 73381 |
| Henrique Monteiro | 72928 |

> **Course:** Sistemas de IoT e Móveis (2025/26)