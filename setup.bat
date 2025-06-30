@echo off
echo 🚀 Setting up JustFlight Downloader...

REM Check if Flutter is installed
flutter --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Flutter is not installed. Please install Flutter first:
    echo    https://flutter.dev/docs/get-started/install
    pause
    exit /b 1
)

REM Check Flutter version
echo ✅ Flutter found. Checking version...
flutter --version

REM Enable desktop support
echo 🖥️  Enabling desktop support...
flutter config --enable-macos-desktop
flutter config --enable-windows-desktop
flutter config --enable-linux-desktop

REM Get dependencies
echo 📦 Installing dependencies...
flutter pub get

REM Generate model files
echo 🔧 Generating model files...
dart run build_runner build --delete-conflicting-outputs

REM Check for any issues
echo 🔍 Running health check...
flutter doctor

echo.
echo ✅ Setup complete! You can now run the application:
echo.
echo    flutter run -d windows  (for Windows)
echo    flutter run -d macos    (for macOS)
echo    flutter run -d linux    (for Linux)
echo.
echo 🎉 Happy coding!
pause
