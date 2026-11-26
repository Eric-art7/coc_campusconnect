# CampusConnect (`coc`) — Flutter + Firebase

University student community app: feed, groups, real-time chat, study rooms with Jitsi video and shared notes,
events, campus assistant, notifications, admin moderation. **Firebase is the whole backend** (Authentication + Cloud Firestore).

This is the original `coc` Flutter project (same package name, same `material_ui` / Dart 3.14 toolchain, same platform folders)
with the CampusConnect app in `lib/`.

## Run it

```bash
cd coc
dart pub global activate flutterfire_cli
npm i -g firebase-tools
firebase login

flutterfire configure          # pick/create your Firebase project, tick: android, ios, web, windows, macos
firebase deploy --only firestore:rules
flutter pub get
flutter run
```

In the [Firebase console](https://console.firebase.google.com) first:
1. Create a project.
2. **Build -> Authentication -> Sign-in method -> Email/Password -> Enable.**
3. **Build -> Firestore Database -> Create database.**

`flutterfire configure` overwrites `lib/firebase_options.dart` and creates `android/app/google-services.json` and the iOS/macOS plist.
Until then the app opens a "Firebase is not configured yet" screen instead of crashing.

The Android application id is `com.example.coc`. Use that when Firebase asks for the app id (or change `applicationId` and
`namespace` in `android/app/build.gradle.kts` *before* running `flutterfire configure`).

## What was changed in your `coc` setup

| File | Change |
|---|---|
| `pubspec.yaml` | + `firebase_core ^5.2.0`, `firebase_auth ^7.1.0`, `cloud_firestore ^7.2.0`, `provider`, `shared_preferences`, `url_launcher`, `intl ^0.20.3`; + `assets/images/`. `name`, `sdk`, `material_ui`, `flutter_lints` untouched. `pubspec.lock` is kept; `flutter pub get` will add the new packages to it. |
| `lib/` | Counter demo replaced by the app. All UI imports `package:material_ui/material_ui.dart` (not `flutter/material.dart`). |
| `android/settings.gradle.kts` | declares the Google Services plugin (`apply false`) |
| `android/app/build.gradle.kts` | applies it only when `google-services.json` exists, so the project still builds before Firebase is set up |
| `AndroidManifest.xml` | `INTERNET` permission, https `<queries>` for opening links, app label |
| `macos/Runner/*.entitlements` | `com.apple.security.network.client` (Firebase needs outgoing network in the sandbox) |
| `web/index.html`, `manifest.json` | app name and theme colour |
| `test/widget_test.dart` | replaced (the counter test referred to `MyApp`) with unit tests that need no Firebase |
| new at root | `firestore.rules`, `firestore.indexes.json`, `firebase.json` |

Platform minimums required by `firebase_core 5.x`: Android minSdk 24 (Flutter's default already), iOS 15 and macOS 11+ (your project: iOS 15.0, macOS 12.0).

## Platform notes

* **Linux:** Firebase has no Linux support. The folder is kept, but the app can't sign in there.
* **Windows:** works (Firebase's Windows support), but the first build downloads the Firebase C++ SDK and is slow.
* **macOS:** Firebase Auth needs the **Keychain Sharing** capability (Xcode -> Runner -> Signing & Capabilities). Without it sign-in fails with a keychain error.
* If `flutterfire configure` also edits the Gradle files, keep only **one** `com.google.gms.google-services` line in `settings.gradle.kts`.

## Becoming an administrator

Admin rights live in Firestore, so nobody can grant them to themselves in the app:
sign up, then in Firestore console -> `users` -> your document -> set `role` to `ADMIN`.
An **Administration** entry appears in the menu (verify universities/government accounts, review reported posts).

## Firestore data model

```
users/{uid}                 fullName, nameLower, nameWords[], fieldOfStudy, yearOfStudy, bio, interests[],
                            role, organization*, searchable, profileVisibility, messageRequests, createdAt
  likes/{postId}  saved/{postId}  following/{uid}  followers/{uid}  notifications/{id}
posts/{id}                  authorId, author, course, body, imageUrl, tag, likeCount, commentCount, createdAt, deletedAt, ...
  comments/{id}
groups/{id}                 name, category, description, ownerId, memberIds[]
studyRooms/{id}             title, topic, startsAt, location, agenda[], ownerId, memberIds[]
  notes/{id}
conversations/{uidA_uidB}   participants[], names{}, lastMessage, lastSenderId, updatedAt
  messages/{id}             senderId, body, createdAt, readAt
events/{id}                 organization*, title, category, description, startsAt, endsAt, location, registrationUrl
reports/{id}                reporterId, postId, message, status
```

No composite indexes are needed.

## Limits of a Firebase-only backend

* No Cloud Functions: like/comment counters and notifications are written by the app. The rules limit what a client can change,
  but for production move them into Cloud Functions.
* "Connections only" / "private" profile visibility and message requests are enforced in the app, not by the rules.
* People search matches the start of a name (or one exact word of it).
* Images are posted as links. For uploads add `firebase_storage` + `image_picker`.
* The assistant is keyword search over campus data (plus links to external research tools), not a generative model.
* Debug builds show an **Add demo content** button on an empty feed.

More detail on what the React/Spring project had and how each part maps: `docs/COMPARISON.md`.
