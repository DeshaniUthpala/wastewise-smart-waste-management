# WasteWise – Smart Waste Management System

This is the implementation of **“WasteWise: Smart Waste Management System”**, a multi‑role Flutter + Firebase application for **citizens, drivers, and admins**.

The system consists of:
- **Citizen mobile app (Flutter)** – request pickups, view schedules, report issues, track status.
- **Driver mobile app (Flutter)** – view assigned pickups, update statuses, share live location.
- **Admin web dashboard (Flutter Web)** – manage citizens, drivers, pickups, schedules, issues, and see live maps.

Backend services are provided by **Firebase Authentication, Cloud Firestore, Firebase Storage, Firebase Cloud Messaging, and Cloud Functions**.

---

## 1. Project Structure (high level)

- `lib/`
  - `screens/` – UI screens for citizen, driver, admin
  - `services/` – low‑level Firebase services (auth, database, storage)
  - `models/` – Dart models for users, drivers, pickupRequests, schedules, issues, etc.
  - `utils/` – colors, localization, helpers
- `functions/` – Firebase Cloud Functions (Node.js) for notifications
- `firestore.rules` – Firestore security rules
- `firebase.json` – Firebase configuration for hosting/functions
- `docs/` – diagrams, pseudo‑code, and design documentation

---

## 2. Prerequisites

- Flutter (latest stable, 3.x)
- Dart SDK (bundled with Flutter)
- Node.js 18+ (for Cloud Functions)
- Firebase CLI (`npm install -g firebase-tools`)
- A Firebase project (this project assumes one is already created)

---

## 3. Firebase Setup

1. **Create Firebase project**
   - Go to `https://console.firebase.google.com`
   - Create a new project (or use `wasteapp-93fd6`).

2. **Enable Authentication**
   - In **Authentication → Sign‑in method**, enable **Email/Password**.

3. **Create Firestore**
   - In **Firestore Database**, create a database in production mode.
   - Location: choose a region close to your users.

4. **Enable Storage**
   - In **Storage**, create a bucket for image uploads (issue photos, etc.).

5. **Enable Cloud Messaging**
   - In **Cloud Messaging**, generate server key if needed for testing.

6. **Add apps**
   - Add **Android**, **iOS**, and **Web** apps to the Firebase project.
   - Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) into the respective folders (already wired in this project).

7. **Configure FlutterFire**
   - From the project root, run:
     ```bash
     flutter pub get
     dart pub global activate flutterfire_cli
     flutterfire configure
     ```
   - Select your Firebase project and target platforms (Android, iOS, Web).
   - This will generate/overwrite `lib/firebase_options.dart`.

8. **Maps API Keys**
   - Create a Google Maps API key from Google Cloud Console.
   - Enable **Maps SDK for Android**, **Maps SDK for iOS**, and **Maps JavaScript API**.
   - Add keys into:
     - `android/app/src/main/AndroidManifest.xml`
     - `ios/Runner/AppDelegate.swift` or `Info.plist`
     - `web/index.html`

---

## 4. Firestore Security Rules

The main Firestore rules are defined in `firestore.rules` and implement:
- Role‑based access (`citizen`, `driver`, `admin`) using `users/{uid}.role`.
- Citizens can:
  - Read/write their own `users/{uid}` document.
  - Create and read only their own `pickupRequests`.
  - Create and read only their own `issues`.
  - Read schedules where `isCommon == true` or `citizenId == uid`.
- Drivers can:
  - Read/Update `drivers/{uid}` and their location.
  - Read assigned `pickupRequests` and update status for those only.
  - Read issues assigned to them.
- Admins can read/write everything.

To deploy rules:
```bash
firebase deploy --only firestore:rules
```

---

## 5. Cloud Functions

Cloud Functions are located in `functions/index.js` and implement:

1. `onPickupRequestCreated`
   - Trigger: `pickupRequests/{pickupId}` `onCreate`
   - Action: notify all admins (create `notifications` docs + send FCM).

2. `onPickupRequestUpdated`
   - Trigger: `pickupRequests/{pickupId}` `onUpdate`
   - If `driverId` changed from null → value → **notify driver + citizen**.
   - If `status` changed → **notify citizen**.

3. `onIssueCreated`
   - Trigger: `issues/{issueId}` `onCreate`
   - Action: notify all admins.

4. `onIssueUpdated`
   - Trigger: `issues/{issueId}` `onUpdate`
   - If `assignedDriverId` changed → **notify driver**.
   - If `status` becomes `resolved` / `closed` → **notify reporter (citizen)**.

Deploy functions:
```bash
cd functions
npm install
firebase deploy --only functions
```

---

## 6. Running the App

From the project root:

```bash
flutter pub get

# Run mobile (citizen/driver)
flutter run -d emulator-5554   # or any connected device

# Run web admin dashboard
flutter run -d chrome
```

The app already includes:
- Citizen flows: login/signup, dashboard, request pickup, schedule, report issue, map view, profile, notifications.
- Driver flows: login, dashboard, assigned pickups, route map, status updates, profile.
- Admin flows: login, dashboard, citizen/driver/pickup/issue/schedule management and maps (see `lib/screens/admin/`).

---

## 7. Repositories & State Management

The codebase currently uses simple service classes (`AuthService`, `DatabaseService`, `StorageService`).  
For a full clean‑architecture setup you can introduce repositories such as:

- `auth_repository.dart`
- `user_repository.dart`
- `pickup_repository.dart`
- `issue_repository.dart`
- `schedule_repository.dart`
- `notification_repository.dart`

Each repository should wrap the low‑level services and expose stream‑based APIs suitable for Riverpod providers or Bloc cubits.

---

## 8. Notes

- Make sure you create at least one **admin user** directly in Firestore (`users` collection with `role: "admin"`) or via a seed script / admin UI.
- Ensure FCM tokens are saved into `users/{uid}.fcmTokens` so that Cloud Functions can send push notifications.
- Indexes for Firestore queries may be required; check Firebase console for suggested indexes after first runs.

