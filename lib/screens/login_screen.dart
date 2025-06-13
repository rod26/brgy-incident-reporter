// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'signup_screen.dart';
import 'dashboard_screen.dart'; // ← import your dashboard

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  static const routeName = '/login';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _formKey   = GlobalKey<FormState>();

  bool   _loading = false;
  String? _error;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error   = null;
    });

    try {
      // 1️⃣ Sign in
      final cred = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: _emailCtrl.text.trim(),
            password: _passCtrl.text,
          );
      final user = FirebaseAuth.instance.currentUser!;
      
      // 2️⃣ Refresh to get latest emailVerified flag
      await user.reload();
      
      // 3️⃣ Check verification
      if (!user.emailVerified) {
        await FirebaseAuth.instance.signOut();
        setState(() {
          _error = 
            'Your email is not verified.\n'
            'Please check your inbox and tap the verification link\n'
            'before logging in.';
        });
        return;
      }

      // 4️⃣ Verified → go to Dashboard
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }

    } on FirebaseAuthException catch (e) {
      // authentication errors
      setState(() => _error = e.message);
    } catch (e) {
      // any other errors
      setState(() => _error = 'An unexpected error occurred.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              Image.asset('assets/branding/logo.png', height: 100),
              const SizedBox(height: 16),
              const Text(
                'Incident Reporter',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Email field
                    TextFormField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => v != null && v.contains('@')
                          ? null
                          : 'Invalid email',
                    ),
                    const SizedBox(height: 16),

                    // Password field
                    TextFormField(
                      controller: _passCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.lock_outline),
                      ),
                      obscureText: true,
                      validator: (v) => v != null && v.length >= 6
                          ? null
                          : 'Min 6 chars',
                    ),

                    // Error / verification message
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Log In button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Log In'),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Forgot password
                    TextButton(
                      onPressed: () {
                        // TODO: forgot password flow
                      },
                      child: const Text('Forgot password?'),
                    ),

                    // Sign Up
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => const SignUpScreen(),
                          ),
                        );
                      },
                      child: const Text("Don't have an account? Sign Up"),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
