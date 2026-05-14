# ResQMove Backend — Setup Guide

## What's in here
A Node.js + Express API backed by SQLite. No cloud account needed — just run it on your laptop.

---

## Step 1 — Install Node.js (if not installed)
Download and install from https://nodejs.org (choose LTS version)

---

## Step 2 — Install backend dependencies
Open Command Prompt, navigate to this folder and run:

```
cd C:\Users\Administrator\Desktop\resqmove-copy\backend
npm install
```

---

## Step 3 — Create demo accounts (run ONCE)
```
node seed.js
```

This creates:
| Role     | Login ID  | Password |
|----------|-----------|----------|
| Driver 1 | DRV-001   | resq123  |
| Driver 2 | DRV-002   | resq123  |
| Patient  | Any phone number (auto-registered on first login) |

---

## Step 4 — Find your PC's IP address
Open Command Prompt and type:
```
ipconfig
```
Look for **IPv4 Address** under your Wi-Fi adapter (e.g. `192.168.1.5`).

---

## Step 5 — Update the Flutter app config
Open this file in your editor:
```
lib/config/app_config.dart
```
Change this line to your PC's IP:
```dart
static const String _serverIp = '192.168.1.100';  // ← put YOUR IP here
```

---

## Step 6 — Start the server
```
node server.js
```
You should see:
```
✅  ResQMove API is running!
   Local:   http://localhost:8000
   Network: http://<YOUR_IP>:8000
```

---

## Step 7 — Run the Flutter app
```
flutter pub get
flutter run
```
Make sure your phone is on the **same Wi-Fi network** as your PC.

---

## Step 8 — Build a signed APK for sharing
```
flutter build apk --release
```
The APK will be at:
```
build/app/outputs/flutter-apk/app-release.apk
```
Share this file — anyone with Android can install it (they need to allow "Install unknown apps" in settings).

---

## API Endpoints Quick Reference
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | /api/v1/auth/patient/login | No | Patient login by phone |
| POST | /api/v1/auth/driver/login | No | Driver login |
| POST | /api/v1/requests | Patient | Submit emergency request |
| GET | /api/v1/requests/active | Patient | Get active request |
| GET | /api/v1/requests/:id/tracking | Patient | Live driver location + ETA |
| PATCH | /api/v1/requests/:id/cancel | Patient | Cancel request |
| GET | /api/v1/driver/requests | Driver | See pending requests |
| POST | /api/v1/driver/requests/:id/accept | Driver | Accept a request |
| POST | /api/v1/driver/trips/:id/complete | Driver | Complete a trip |
| POST | /api/v1/driver/location | Driver | Push GPS location |
| PATCH | /api/v1/driver/status | Driver | Go online/offline |
| GET | /api/v1/stats | Public | App stats for home screen |

---

## For Railway deployment (after presentation)
1. Push the `backend/` folder to a GitHub repo
2. Create a new project on Railway, connect the repo
3. Add env var: `JWT_SECRET=your-strong-random-string`
4. Railway auto-detects Node.js and runs `npm start`
5. Update `_serverIp` in `app_config.dart` with the Railway URL
