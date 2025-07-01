# JustFlight Downloader - Makefile
# Available targets:

help:
	@echo "🚀 JustFlight Downloader - Available Commands:"
	@echo ""
	@echo "📦 Setup & Development:"
	@echo "  setup           - Install dependencies and build"
	@echo "  run             - Run the app on macOS"
	@echo "  debug           - Run in debug mode"
	@echo "  clean           - Clean build artifacts"
	@echo "  analyze         - Run code analysis"
	@echo ""
	@echo "🧪 Testing & Analysis:"
	@echo "  test-product-page - Test product page structure analysis"
	@echo "  analyze-html     - Analyze captured HTML files"
	@echo ""
	@echo "🔧 Utilities:"
	@echo "  restart-app     - Kill and restart Flutter app"
	@echo "  dev-setup       - Clean setup for development" 
	@echo "  debug-run       - Run with auto-filled credentials (requires credentials.txt)"
	@echo "  disable-autofill - Disable auto-fill for production"
	@echo ""

setup:
	flutter pub get
	dart run build_runner build
	./setup.sh

run:
	flutter run -d macos

# Debug and development commands
debug:
	flutter run -d macos --debug

run-verbose:
	flutter run -d macos -v

clean:
	flutter clean
	flutter pub get

analyze:
	flutter analyze

test:
	flutter test

build-debug:
	flutter build macos --debug

build-release:
	flutter build macos --release

# Platform specific runs
run-windows:
	flutter run -d windows

run-linux:
	flutter run -d linux

# Development helpers
dev-setup: clean
	dart run build_runner build --delete-conflicting-outputs
	flutter analyze

# Testing and debugging - Useful scripts
test-product-page:
	@echo "🧪 Testing product page structure (requires credentials.txt)..."
	@echo "This script analyzes the actual JustFlight product download page structure"
	dart run test_product_page_standalone.dart

analyze-html:
	@echo "📋 Analyzing captured HTML files..."
	dart run analyze_html_files.dart

# Development helpers
restart-app:
	@echo "Stopping any running Flutter processes..."
	@pkill -f "flutter" || true
	@sleep 2
	@echo "Starting fresh Flutter app..."
	flutter run -d macos

# Debug with auto-fill credentials
debug-run:
	@if [ ! -f credentials.txt ]; then \
		echo "❌ credentials.txt not found. Create it with your email and password on separate lines."; \
		exit 1; \
	fi
	@echo "🐛 Running with auto-filled credentials (debug mode)..."
	@echo "📁 Copying credentials to app sandbox..."
	@mkdir -p "/Users/bcraig/Library/Containers/com.example.jfdownloader/Data" || true
	@cp credentials.txt "/Users/bcraig/Library/Containers/com.example.jfdownloader/Data/credentials.txt" || echo "Note: Sandbox directory may not exist until first run"
	@echo "Login will be automatically filled from credentials.txt"
	flutter run -d macos

# Disable auto-fill for production
disable-autofill:
	@echo "🔒 Disabling auto-fill for production..."
	@sed -i '' 's/static const bool _debugAutoFill = true;/static const bool _debugAutoFill = false;/' lib/screens/login_screen.dart
	@echo "✅ Auto-fill disabled. Remember to remove or secure credentials.txt before deployment."

.PHONY: help setup run debug run-verbose clean analyze test build-debug build-release run-windows run-linux dev-setup test-product-page analyze-html restart-app debug-run disable-autofill