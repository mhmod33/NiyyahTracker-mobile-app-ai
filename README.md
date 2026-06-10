# 🤍 Basair (بصائر — متابع النوايا)

**Basair** is a spiritual development app that helps users track daily worship, set goals, and stay consistent in their religious journey.

Built with **Flutter** and **Firebase**, with a polished Arabic-first UI focused on day-by-day spiritual growth.

---

## 🌟 Features

### 🕌 Core Experience
- **📿 Daily Worship:** Record prayers, remembrances, Quran, charity, voluntary fasting, and night prayers with a daily worship card.
- **🎯 Monthly Spiritual Goals:** Set a goal at the start of the month and track progress visually.
- **📅 Smart Weekly Plan:** Goal-based daily tasks (e.g. pages to read to finish the Quran on time).
- **📊 Analytics Dashboard:** Weekly and monthly charts of worship activity.
- **📄 Spiritual Reports:** Monthly PDF summary with achievements and motivation.
- **🌙 Ramadan Mode:** Suhoor/Iftar times, Taraweeh tracker, Laylat al-Qadr countdown, and a 30-day plan.
- **🕋 Hajj Mode:** Holy sites guide, ritual steps, countdowns, and supplications.
- **🔔 Smart Notifications:** Prayer times, morning/evening remembrances, wird reminders, and inactivity alerts.
- **👤 Guest Mode:** Browse many features without signing in; sign in to unlock personal tracking and sync.

### 📖 Quran & Audio
- **📗 Holy Quran:** Full mushaf reader with surah index and navigation.
- **🎧 Quran Reciters (مزامير القرآن):** Stream or download full reciters (Mishary Alafasy, Maher Al Muaiqly, Al-Husary, Al-Minshawi).
- **☁️ Shared Snippets (مقتطفات بصائر):** Admin-curated audio clips stored as links in **Firestore** — visible to **all users and guests**, streamed on demand.
- **🔗 SoundCloud support:** Paste a public SoundCloud URL (`soundcloud.com`, `on.soundcloud.com`); the app resolves it to a direct stream when playing.
- **⬇️ Offline downloads:** Download full reciters or individual snippet tracks for offline listening.
- **🎵 Mini player:** Background playback with play/pause, next/previous, and seek.

### 🧭 Worship Tools
- **🕐 Prayer Times & Azan:** Prayer schedule and customizable azan notifications.
- **🧭 Qibla:** Compass direction to the Kaaba.
- **🕌 Nearby Mosques:** Find mosques on the map.
- **📿 Azkar Library:** Morning/evening remembrances with a counter.
- **📖 Daily Wird:** Personal wird tracking (signed-in users).
- **🎯 Goals, Challenges, Study Tracker:** Spiritual goals, challenges, and study playlists.

### 🛡️ Admin Panel
Available to accounts with `role: admin` in Firestore:
- **إدارة صلاحية الرفع:** Grant or revoke upload permission (`canUpload`) for any user — controls who can add, edit, and delete shared SoundCloud/audio links.
- **Send notifications:** Push admin announcements to users.
- **Add / edit / delete snippets:** Manage the shared audio library from **مزامير القرآن** (admin always has access; other users need `canUpload`).

#### Shared library permissions

| Role | View snippets | Add / edit / delete |
|------|---------------|---------------------|
| Guest | ✅ | ❌ |
| Signed-in user | ✅ | ❌ |
| User with `canUpload` | ✅ | ✅ |
| Admin | ✅ | ✅ |

Links are metadata only (`remoteUrl` in Firestore collection `library_snippets`) — no audio files uploaded to Firebase Storage.

Supported link types:
- **SoundCloud** page links (resolved at playback time)
- **Direct audio URLs** (`.mp3`, `.m4a`, `.m3u8`)

See **[ADMIN_SETUP.md](ADMIN_SETUP.md)** for admin account setup, Firestore rules deployment, and upload workflow.

---

## 🎨 Design System

- **Primary:** Dark Green (`#1B4332`)
- **Secondary:** Gold (`#B7950B`)
- **Background:** Light Greenish White (`#F0FDF4`)
- **Typography:** IBM Plex Sans Arabic (UI) & Amiri (Quran text) via Google Fonts
- **Direction:** RTL (Arabic-first)

---

## 🏗️ Project Structure

```
lib/
├── core/           # Theme, colors, shared UI helpers
├── config/         # Admin bootstrap emails, database config
├── features/       # Feature modules (auth, dashboard, quran, admin, …)
├── providers/      # AppAuthProvider, ThemeProvider, …
├── services/       # Firebase, audio, notifications, shared library, …
└── widgets/        # Mini player and reusable components
```

Key services for the shared audio library:
- `lib/services/shared_library_service.dart` — Firestore CRUD for `library_snippets`
- `lib/services/quran_audio_service.dart` — Playback, caching, reciter management
- `lib/services/audio_link_resolver.dart` — SoundCloud → stream URL resolution

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart ^3.11.5)
- A [Firebase](https://console.firebase.google.com) project with **Authentication** and **Firestore** enabled

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/mhmod33/Basair-mobile-app-ai.git
   cd Basair-mobile-app-ai
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Configure Firebase (if not already set up):
   - Add `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - Or run `flutterfire configure` to regenerate `lib/firebase_options.dart`

4. Deploy Firestore rules (required for shared library & admin):
   - Firebase Console → **Firestore** → **Rules**
   - Paste contents of [`firestore.rules`](firestore.rules) → **Publish**

5. Set up an admin account — see **[ADMIN_SETUP.md](ADMIN_SETUP.md)**

6. Run the app:
   ```bash
   flutter run
   ```

### Pre-release checklist (shared audio library)

1. Publish `firestore.rules` to Firebase.
2. Confirm admin UID has `role: "admin"` in Firestore `users` collection.
3. Admin adds a test SoundCloud link in **مزامير القرآن**.
4. Verify the document appears in Firestore → `library_snippets`.
5. **Clear app data** on a second device → open as **guest** → links should still appear.
6. Confirm non-admin users do **not** see add/edit/delete buttons.
7. Grant `canUpload` from **إدارة صلاحية الرفع** and verify that user can manage links.

---

## 🛠️ Technology Stack

| Layer | Technology |
|-------|------------|
| Framework | Flutter (Material 3) |
| Language | Dart |
| State management | Provider (`ChangeNotifier`) |
| Local storage | Hive |
| Backend | Firebase Auth, Cloud Firestore |
| Audio | `just_audio`, `audio_session` |
| SoundCloud | `soundcloud_explode_dart` |
| Charts | fl_chart |
| Maps / location | geolocator, flutter_map |
| Notifications | flutter_local_notifications |
| PDF reports | pdf, printing |
| Localization | flutter_localizations (Arabic primary) |

---

## 🤝 Contribution

Contributions are welcome! Please open an issue or submit a Pull Request.

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

*🤍 "ارسم رحلتك الروحية — يوماً بيوم"*
