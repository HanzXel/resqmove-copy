# ResQMove — Release Keystore Setup

Run these steps ONE TIME before building a release APK.

---

## Step 1 — Generate the keystore

Open **Command Prompt** (not PowerShell) inside the `android/app/` folder and run:

```
keytool -genkey -v -keystore resqmove-release.jks -keyAlg RSA -keysize 2048 -validity 10000 -alias resqmove
```

It will ask for:
- A keystore password (remember this — you need it every build)
- Your name / org / city / country (press Enter to skip any field)
- Confirm the key password (press Enter to use the same as the keystore password)

The file `resqmove-release.jks` will be created inside `android/app/`.

**IMPORTANT:** Never commit this file to Git. It is already in .gitignore.

---

## Step 2 — Find your PC's local IP address

Open Command Prompt and run:

```
ipconfig
```

Look for **IPv4 Address** under your Wi-Fi adapter, e.g. `192.168.1.5`.
You will need this to run the app on a real phone.

---

## Step 3 — Set environment variables (PowerShell)

Open **PowerShell** and paste (replace the passwords with your own):

```powershell
$env:KEYSTORE_PATH    = "resqmove-release.jks"
$env:KEYSTORE_PASSWORD = "your_store_password"
$env:KEY_ALIAS        = "resqmove"
$env:KEY_PASSWORD     = "your_key_password"
```

---

## Step 4 — Build the release APK

From the project root (same PowerShell window where you set the env vars):

**Option A — LAN backend (phone + PC on same Wi-Fi):**
```powershell
flutter build apk --release --dart-define=API_BASE_URL=http://192.168.X.X:8000/api/v1 --dart-define=HOTLINE_NUMBER=+639XXXXXXXXX --dart-define=HOTLINE_DISPLAY="+63 9XX XXX XXXX"
```
Replace `192.168.X.X` with the IP from Step 2 and `node server.js` must be running on your PC.

**Option B — Deployed backend (Railway / VPS):**
```powershell
flutter build apk --release --dart-define=API_BASE_URL=https://your-backend.railway.app/api/v1 --dart-define=HOTLINE_NUMBER=+639XXXXXXXXX --dart-define=HOTLINE_DISPLAY="+63 9XX XXX XXXX"
```

**Option C — Mock mode (no backend, for UI testing only):**
```powershell
flutter build apk --release --dart-define=USE_MOCK_API=true
```

---

## Step 5 — Find the APK

After a successful build, the APK is at:
```
build\app\outputs\flutter-apk\app-release.apk
```

Share this file directly. Recipients must allow **"Install unknown apps"** in Android settings.

---

## For Google Play Store

Build an App Bundle instead:
```powershell
flutter build appbundle --release --dart-define=API_BASE_URL=https://your-backend.com/api/v1
```
