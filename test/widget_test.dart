import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jfdownloader/main.dart';

void main() {
  testWidgets('App launches and shows login screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the login screen is displayed by looking for the title
    expect(find.text('JustFlight Downloader'), findsOneWidget);
    
    // Verify that email and password fields are present
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    
    // Verify that the sign in button is present
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('Email validation works', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Find the email field and enter invalid email
    final emailField = find.ancestor(
      of: find.text('Email'),
      matching: find.byType(TextFormField),
    ).first;
    
    await tester.enterText(emailField, 'invalid-email');
    
    // Tap the sign in button to trigger validation
    await tester.tap(find.text('Sign In'));
    await tester.pump();

    // Should show validation error
    expect(find.text('Please enter a valid email'), findsOneWidget);
  });
}
