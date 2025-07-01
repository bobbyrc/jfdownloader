import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

/// Login screen with debug auto-fill functionality
/// 
/// To disable auto-fill for production:
/// 1. Set _debugAutoFill = false
/// 2. Remove or secure the credentials.txt file

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String _autoFillStatus = 'Loading...';
  
  // Debug flag - set to true to auto-fill credentials for testing
  // WARNING: Set to false before production release!
  static const bool _debugAutoFill = true;

  @override
  void initState() {
    super.initState();
    if (_debugAutoFill) {
      _loadCredentialsForTesting();
    }
  }

  Future<void> _loadCredentialsForTesting() async {
    if (mounted) {
      setState(() {
        _autoFillStatus = 'Searching for credentials...';
      });
    }
    
    try {
      final currentDir = Directory.current.path;
      print('Searching for credentials file...');
      print('Current working directory: $currentDir');
      
      // Try multiple possible locations for the credentials file
      // When running Flutter in sandbox, we need to look in the app's data directory
      final possiblePaths = [
        'credentials.txt', // In the app's current directory (sandbox)
        '$currentDir/credentials.txt', // Explicit current directory
        '/Users/bcraig/code/jfdownloader/credentials.txt', // Original project location (may not work in sandbox)
        '../credentials.txt', // One level up
        '../../credentials.txt', // Two levels up
      ];
      
      File? credentialsFile;
      String? foundPath;
      
      for (final path in possiblePaths) {
        final file = File(path);
        print('Checking: $path');
        try {
          if (await file.exists()) {
            credentialsFile = file;
            foundPath = path;
            print('✅ Found credentials file at: $path');
            break;
          } else {
            print('❌ Not found: $path');
          }
        } catch (e) {
          print('❌ Cannot access: $path (${e.toString()})');
        }
      }
      
      if (credentialsFile != null && foundPath != null) {
        final lines = await credentialsFile.readAsLines();
        print('Read ${lines.length} lines from credentials file');
        
        if (lines.length >= 2) {
          final email = lines[0].trim();
          final password = lines[1].trim();
          
          _emailController.text = email;
          _passwordController.text = password;
          
          print('✅ Auto-filled credentials: ${email.substring(0, 3)}***@${email.split('@').last}');
          
          if (mounted) {
            setState(() {
              _autoFillStatus = 'Credentials loaded ✅';
            });
          }
        } else {
          print('❌ Credentials file found but does not have enough lines (needs email and password on separate lines)');
          if (mounted) {
            setState(() {
              _autoFillStatus = 'Invalid file format (need 2 lines)';
            });
          }
        }
      } else {
        print('❌ Credentials file not found in any location');
        print('💡 Tip: Copy credentials.txt to the app\'s working directory: $currentDir');
        if (mounted) {
          setState(() {
            _autoFillStatus = 'File not found - check console';
          });
        }
      }
    } catch (e) {
      print('❌ Error loading credentials: $e');
      if (mounted) {
        setState(() {
          _autoFillStatus = 'Error: ${e.toString().substring(0, 30)}...';
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.1),
              Theme.of(context).colorScheme.secondary.withOpacity(0.1),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Card(
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.flight_takeoff,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'JustFlight Downloader',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in to access your purchased products',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      // Debug indicator
                      if (_debugAutoFill) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.bug_report_outlined,
                                size: 16,
                                color: Colors.orange[700],
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Debug Mode: $_autoFillStatus',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 32),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                hintText: 'Enter your JustFlight email',
                                prefixIcon: Icon(Icons.email),
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your email';
                                }
                                if (!value.contains('@')) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                hintText: 'Enter your password',
                                prefixIcon: const Icon(Icons.lock),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                                border: const OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password';
                                }
                                return null;
                              },
                              onFieldSubmitted: (_) => _handleLogin(),
                            ),
                            const SizedBox(height: 24),
                            Consumer<AuthProvider>(
                              builder: (context, authProvider, child) {
                                if (authProvider.error != null) {
                                  return Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    margin: const EdgeInsets.only(bottom: 16),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.errorContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.error_outline,
                                          color: Theme.of(context).colorScheme.onErrorContainer,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            authProvider.error!,
                                            style: TextStyle(
                                              color: Theme.of(context).colorScheme.onErrorContainer,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close),
                                          onPressed: authProvider.clearError,
                                          color: Theme.of(context).colorScheme.onErrorContainer,
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                            SizedBox(
                              width: double.infinity,
                              child: Consumer<AuthProvider>(
                                builder: (context, authProvider, child) {
                                  return ElevatedButton(
                                    onPressed: authProvider.isLoading ? null : _handleLogin,
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: authProvider.isLoading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Text(
                                            'Sign In',
                                            style: TextStyle(fontSize: 16),
                                          ),
                                  );
                                },
                              ),
                            ),
                            
                            // Debug: Clear credentials button
                            if (_debugAutoFill) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextButton(
                                      onPressed: () {
                                        _emailController.clear();
                                        _passwordController.clear();
                                      },
                                      child: const Text(
                                        'Clear Fields',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextButton(
                                      onPressed: _loadCredentialsForTesting,
                                      child: const Text(
                                        'Load Credentials',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Don\'t have an account? Visit justflight.com to create one.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (success && mounted) {
      // Navigation will be handled automatically by the Consumer in main.dart
    }
  }
}
