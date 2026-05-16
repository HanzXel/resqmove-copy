# ResQMove — App Icon & Splash Assets

Place your PNG files here before running the icon/splash generators.

## Required files

| File | Size | Purpose |
|------|------|---------|
| `app_icon.png` | 1024×1024 px | Full launcher icon (square, no transparency) |
| `app_icon_foreground.png` | 1024×1024 px | Adaptive icon foreground (safe zone = center 66%) |
| `splash_logo.png` | 512×512 px | Centered logo on the dark splash screen |

## After adding the files, run these two commands:

    flutter pub get
    dart run flutter_launcher_icons
    dart run flutter_native_splash:create

## Tips
- Use a red cross / ambulance logo on a transparent background for the foreground icon
- The adaptive icon background is already set to #0D1B2A (dark navy) in pubspec.yaml
- The splash background is also #0D1B2A
