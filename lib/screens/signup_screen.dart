// lib/screens/signup_screen.dart

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ← adjust this to match your actual package name in pubspec.yaml
import 'package:incident_reporter/screens/login_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  static const routeName = '/signup';

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameCtrl    = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _formKey     = GlobalKey<FormState>();

  bool _agreed  = false;
  bool _loading = false;
  String? _error;

  Future<void> _register() async {
    // 1) Validate form + terms
    if (!_formKey.currentState!.validate() || !_agreed) {
      setState(() {
        if (!_agreed) _error = 'You must agree to the Terms & Conditions.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error   = null;
    });

    try {
      // 2) Create user in Firebase Auth
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailCtrl.text.trim(),
            password: _passCtrl.text,
          );
      final user = cred.user!;

      // 3) Write user record to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'uid'           : user.uid,
        'fullName'      : _nameCtrl.text.trim(),
        'email'         : user.email,
        'createdAt'     : FieldValue.serverTimestamp(),
        'emailVerified' : user.emailVerified,
      });

      // 4) Send verification email
      await user.sendEmailVerification();

      // 5) Notify success and go back to login
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text(
              'Registration successful!\n'
              'Verification link sent to your email.\n'
              'Please verify before logging in.'
            ),
          ),
        );
        await Future.delayed(const Duration(seconds: 2));
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
    on FirebaseAuthException catch (e) {
      // Auth-specific errors
      setState(() => _error = e.message);
    }
    catch (e, st) {
      // 🔥 Log any other unexpected error + stack trace
      print('🔥 Firestore/write failed: $e\n$st');
      setState(() => _error = 'An unexpected error occurred.');
    }
    finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showTerms() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Terms & Conditions'),
        content: SingleChildScrollView(
          child: Text(
            'By registering, you agree to share your personal data—'
            'including full name and email—with the Incident Reporter app. '
            'This data is stored securely in our Firebase Firestore database '
            'for authentication, user management, and incident notifications. '
            'You may request correction or deletion of your data at any time '
            'by contacting support.',
            style: const TextStyle(fontSize: 14),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 32),
                Image.asset('assets/branding/logo.png', height: 100),
                const SizedBox(height: 16),
                const Text(
                  'Incident Reporter',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),

                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Full Name
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            v != null && v.isNotEmpty ? null : 'Enter your name',
                      ),
                      const SizedBox(height: 16),

                      // Email
                      TextFormField(
                        controller: _emailCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) =>
                            v != null && v.contains('@') ? null : 'Invalid email',
                      ),
                      const SizedBox(height: 16),

                      // Password
                      TextFormField(
                        controller: _passCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                        validator: (v) =>
                            v != null && v.length >= 6 ? null : 'Min 6 characters',
                      ),
                      const SizedBox(height: 16),

                      // Confirm Password
                      TextFormField(
                        controller: _confirmCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Confirm Password',
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                        validator: (v) => v == _passCtrl.text
                            ? null
                            : 'Passwords do not match',
                      ),
                      const SizedBox(height: 16),

                      // Terms & Conditions link
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text.rich(
                          TextSpan(
                            style: Theme.of(context).textTheme.bodyMedium,
                            children: [
                              const TextSpan(text: 'I agree to the '),
                              TextSpan(
                                text: 'Terms & Conditions',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Colors.blue,
                                      decoration: TextDecoration.underline,
                                    ),
                                recognizer: TapGestureRecognizer()..onTap = _showTerms,
                              ),
                            ],
                          ),
                        ),
                        value: _agreed,
                        onChanged: (v) => setState(() => _agreed = v ?? false),
                      ),

                      // Error message
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),

                      // Register button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _register,
                          child: _loading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('Register'),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Already have an account?
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                          );
                        },
                        child: const Text('Already have an account? Log In'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
