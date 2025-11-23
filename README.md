# freetask-app-3

This repository contains the Flutter project scaffold for the **FreeTask App**.

## Getting started

The Flutter application lives in the [`freetask_app`](freetask_app/) directory. To fetch
dependencies and run the project locally, make sure you have the Flutter SDK installed,
then execute:

```bash
cd freetask_app
flutter pub get
```

The backend runs on port **4000** by default. Flutter will pick sensible defaults
per platform, but you can override them using `API_BASE_URL`:

* **Android emulator** (default: `http://10.0.2.2:4000`)

  ```bash
  flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:4000
  ```

* **Web / Chrome** (default: `http://localhost:4000`)

  ```bash
  flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:4000
  ```
