#!/bin/bash

# JustFlight Downloader Setup Script
# This script helps set up the development environment

echo "🚀 Setting up JustFlight Downloader..."

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed. Please install Flutter first:"
    echo "   https://flutter.dev/docs/get-started/install"
    exit 1
fi

# Check Flutter version
echo "✅ Flutter found. Checking version..."
flutter --version

# Enable desktop support
echo "🖥️  Enabling desktop support..."
flutter config --enable-macos-desktop
flutter config --enable-windows-desktop
flutter config --enable-linux-desktop

# Get dependencies
echo "📦 Installing dependencies..."
flutter pub get

# Generate model files
echo "🔧 Generating model files..."
dart run build_runner build --delete-conflicting-outputs

# Check for any issues
echo "🔍 Running health check..."
flutter doctor

echo ""
echo "✅ Setup complete! You can now run the application:"
echo ""
echo "   flutter run -d macos    (for macOS)"
echo "   flutter run -d windows  (for Windows)" 
echo "   flutter run -d linux    (for Linux)"
echo ""
echo "🎉 Happy coding!"
