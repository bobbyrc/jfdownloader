# JustFlight Downloader

A cross-platform desktop application for downloading your purchased products from JustFlight.com.

## Features

- 🔐 Secure login with your JustFlight account
- 📦 View all your purchased products in an organized grid
- 🔍 Search and filter products by name, description, or category
- ⬇️ Download products with progress tracking
- 🚀 Multiple concurrent downloads with configurable limits
- 💾 Choose custom download locations
- 🎨 Modern, responsive UI with dark/light theme support
- 🖥️ Cross-platform support (Windows, macOS, Linux)

## Installation

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.0.0 or later)
- Dart SDK (included with Flutter)

### Setup

## Getting Started

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/jfdownloader.git
   cd jfdownloader
   ```

2. Set up the project (installs dependencies, builds models, and sets up environment):
   ```bash
   make setup
   ```

3. Create a credentials file for testing (optional):
   ```bash
   echo "your-email@example.com" > credentials.txt
   echo "your-password" >> credentials.txt
   ```

4. Run the application:
   ```bash
   make run
   ```

### Available Commands

Run `make help` to see all available commands:

- **Setup & Development:**
  - `make setup` - Install dependencies and build
  - `make run` - Run the app on macOS
  - `make debug` - Run in debug mode
  - `make clean` - Clean build artifacts
  - `make analyze` - Run code analysis

- **Testing & Analysis:**
  - `make test-product-page` - Test product page structure analysis
  - `make analyze-html` - Analyze captured HTML files

- **Utilities:**
  - `make restart-app` - Kill and restart Flutter app
  - `make dev-setup` - Clean setup for development
   flutter run -d windows  # For Windows
   flutter run -d linux    # For Linux
   ```

## Building for Release

### macOS
```bash
flutter build macos --release
```

### Windows
```bash
flutter build windows --release
```

### Linux
```bash
flutter build linux --release
```

## Usage

1. **Login**: Enter your JustFlight account credentials
2. **Browse**: View your purchased products in the main interface
3. **Search**: Use the search bar to find specific products
4. **Filter**: Select categories to narrow down your product list
5. **Download**: Click the download button and choose your destination folder
6. **Monitor**: Track download progress in the download panel

## Architecture

The application follows a clean architecture pattern with:

- **Models**: Data structures for products and download progress
- **Providers**: State management using the Provider pattern
- **Services**: HTTP clients for JustFlight API and download management
- **Screens**: Main UI screens (login, main dashboard)
- **Widgets**: Reusable UI components

## Web Scraping Approach

The application uses web scraping to interact with the JustFlight website since no official API is available. It:

1. Authenticates using the standard login form
2. Parses the user's download page to extract product information
3. Follows download links to access files
4. Maintains session cookies for authenticated requests

## Security and Privacy

- Credentials are only used for authentication and are not stored permanently
- Session cookies are stored locally and cleared on logout
- All communication uses HTTPS
- No personal data is transmitted to third parties

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## Disclaimer

This application is an unofficial tool for accessing your own purchased products from JustFlight. It is not affiliated with or endorsed by JustFlight. Please ensure you comply with JustFlight's terms of service when using this application.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues and feature requests, please use the GitHub Issues page.

## Technical Details

### Dependencies

- **flutter**: Cross-platform UI framework
- **provider**: State management
- **dio**: HTTP client with advanced features
- **html**: HTML parsing for web scraping
- **window_manager**: Desktop window management
- **path_provider**: Platform-specific paths
- **file_picker**: File and directory selection

### Platform Support

- **macOS**: 10.14 or later
- **Windows**: Windows 10 or later
- **Linux**: Ubuntu 18.04 or later (or equivalent)

### Performance

- Efficient memory usage with lazy loading
- Concurrent downloads with configurable limits
- Responsive UI with smooth animations
- Optimized network requests with connection pooling
