# Tashila Mobile Applications - Deployment Guide

This archive contains the complete source code for both Tashila mobile applications:
- **`tashila_client`**: The Passenger / Customer application (Android & iOS)
- **`tashila_driver`**: The Driver application (Android & iOS)

---

## Prerequisites

- **Flutter SDK**: `>= 3.10.1` (Recommended: Flutter 3.24.x or latest stable)
- **Dart SDK**: Compatible with Flutter SDK
- **For Android deployment**: Android Studio, Android SDK (API 34+), Java 17
- **For iOS deployment**: macOS machine with Xcode 15+, CocoaPods (`sudo gem install cocoapods`)

---

## 1. Client App (`tashila_client`)

### Android Build (Google Play Store)

1. Open a terminal in `tashila_client`:
   ```bash
   cd tashila_client
   flutter pub get
   ```

2. Configure keystore for release signing in `android/key.properties` and `android/app/build.gradle`:
   - Store your `.jks` file in `android/app/`
   - Configure `keyAlias`, `keyPassword`, `storeFile`, `storePassword` in `android/key.properties`

3. Build the Android App Bundle:
   ```bash
   flutter build appbundle --release
   ```
   Output: `build/app/outputs/bundle/release/app-release.aab`

4. Upload the generated `.aab` file to **Google Play Console**.

---

### iOS Build (Apple App Store)

1. Open terminal on macOS:
   ```bash
   cd tashila_client
   flutter pub get
   cd ios
   pod install
   cd ..
   ```

2. Open `ios/Runner.xcworkspace` in **Xcode**:
   - Select the `Runner` target
   - Under **Signing & Capabilities**:
     - Choose your Apple Developer Team
     - Set your Bundle Identifier (e.g. `com.tashila.client`)
     - Ensure valid Provisioning Profile is selected

3. Build IPA or Archive via Xcode:
   ```bash
   flutter build ipa --release
   ```
   Or in Xcode: `Product -> Archive -> Distribute App -> App Store Connect`.

---

## 2. Driver App (`tashila_driver`)

### Android Build (Google Play Store)

1. Open a terminal in `tashila_driver`:
   ```bash
   cd tashila_driver
   flutter pub get
   ```

2. Configure release keystore signing in `android/key.properties` and `android/app/build.gradle`.

3. Build the Android App Bundle:
   ```bash
   flutter build appbundle --release
   ```
   Output: `build/app/outputs/bundle/release/app-release.aab`

4. Upload the `.aab` file to **Google Play Console**.

---

### iOS Build (Apple App Store)

1. Open terminal on macOS:
   ```bash
   cd tashila_driver
   flutter pub get
   cd ios
   pod install
   cd ..
   ```

2. Open `ios/Runner.xcworkspace` in **Xcode**:
   - Select the `Runner` target
   - Under **Signing & Capabilities**:
     - Choose your Apple Developer Team
     - Set your Bundle Identifier (e.g. `com.tashila.driver`)
     - Ensure valid Provisioning Profile is selected
   - Verify background location and notification permissions in `Info.plist`

3. Build IPA or Archive via Xcode:
   ```bash
   flutter build ipa --release
   ```
   Or in Xcode: `Product -> Archive -> Distribute App -> App Store Connect`.

---

## 3. Backend & API Configuration

Both apps are pre-configured with the production backend:
- File: `lib/core/config/api_config.dart`
- URL: `https://web-production-da6bc.up.railway.app`

If you deploy your own backend server, simply update `kApiBaseUrl` in both `api_config.dart` files.
