# Getting Started with JustFlight Downloader

This guide will help you set up and run the JustFlight Downloader application.

## Prerequisites

1. **Flutter SDK**: Download and install Flutter from [flutter.dev](https://flutter.dev/docs/get-started/install)
2. **Git**: For cloning the repository
3. **JustFlight Account**: You'll need valid credentials for justflight.com

## Quick Setup

### Option 1: Using the Setup Script

Run the setup script to automatically configure everything:

**macOS/Linux:**
```bash
./setup.sh
```

**Windows:**
```batch
setup.bat
```

### Option 2: Manual Setup

1. **Clone the repository:**
   ```bash
   git clone <your-repo-url>
   cd jfdownloader
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Enable desktop support:**
   ```bash
   flutter config --enable-macos-desktop
   flutter config --enable-windows-desktop
   flutter config --enable-linux-desktop
   ```

4. **Generate model files:**
   ```bash
   dart run build_runner build
   ```

## Running the Application

### Development Mode

Run the application in development mode:

```bash
# For macOS
flutter run -d macos

# For Windows
flutter run -d windows

# For Linux
flutter run -d linux
```

### Building for Release

Create a release build:

```bash
# For macOS
flutter build macos --release

# For Windows
flutter build windows --release

# For Linux
flutter build linux --release
```

## First Time Usage

1. **Launch the application**
2. **Login**: Enter your JustFlight account credentials
3. **Browse**: Your purchased products will be displayed
4. **Download**: Click the download button on any product and choose a destination folder

## Features Overview

### Authentication
- Secure login with JustFlight credentials
- Session management with cookies
- Automatic logout functionality

### Product Management
- Grid view of all purchased products
- Search functionality across product names and descriptions
- Category filtering
- Product images and details

### Download Management
- Multiple concurrent downloads
- Progress tracking with speed and size information
- Pause, resume, and cancel downloads
- Download queue management
- Configurable concurrent download limits

### UI Features
- Modern Material Design 3 interface
- Dark and light theme support
- Responsive layout
- Real-time download progress
- Error handling and user feedback

## Troubleshooting

### Common Issues

1. **Flutter not found**
   - Ensure Flutter is installed and added to your PATH
   - Run `flutter doctor` to check your installation

2. **Build errors**
   - Run `flutter clean` and then `flutter pub get`
   - Regenerate models with `dart run build_runner build --delete-conflicting-outputs`

3. **Login issues**
   - Verify your JustFlight credentials
   - Check your internet connection
   - Ensure JustFlight website is accessible

4. **Download failures**
   - Check available disk space
   - Verify download directory permissions
   - Check internet connection stability

### Debug Mode

For debugging, run with verbose output:

```bash
flutter run -v -d <platform>
```

### Logs

Application logs are displayed in the console during development. For release builds, logs are stored in the system's application data directory.

## Configuration

### Download Settings
- **Concurrent Downloads**: Adjust in Settings menu (1-10 simultaneous downloads)
- **Download Location**: Choose per download or set a default folder

### Performance
- The application is optimized for desktop use
- Memory usage scales with the number of products
- Network requests are optimized with connection pooling

## Security Notes

- Credentials are only used for authentication and are not stored permanently
- Session cookies are stored locally and cleared on logout
- All communication uses HTTPS
- No personal data is transmitted to third parties

## Development

### Project Structure
```
lib/
├── main.dart                 # Application entry point
├── models/                   # Data models
├── providers/                # State management
├── services/                 # Business logic and API
├── screens/                  # Main UI screens
└── widgets/                  # Reusable UI components
```

### Key Technologies
- **Flutter**: Cross-platform UI framework
- **Provider**: State management
- **Dio**: HTTP client with cookie support
- **HTML Parser**: Web scraping functionality
- **Window Manager**: Desktop window management

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Disclaimer

This is an unofficial tool for accessing your own purchased products from JustFlight. Please ensure compliance with JustFlight's terms of service.
