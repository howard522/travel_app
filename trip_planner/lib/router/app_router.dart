// lib/router/app_router.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../pages/sign_in_page.dart';
import '../pages/home_page.dart';
import '../pages/profile_page.dart';
import '../pages/trip_page.dart';
import '../pages/expense_page.dart';

final appRouter = GoRouter(
  refreshListenable: _GoRouterRefresh(),
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const SignInPage()),
    GoRoute(
      path: '/',
      builder: (_, __) => const HomePage(),
      routes: [
        GoRoute(path: 'profile', builder: (_, __) => const ProfilePage()),
        GoRoute(
          path: 'trip/:id',
          builder: (_, state) =>
              TripPage(tripId: state.pathParameters['id']!),
          routes: [
            GoRoute(
              path: 'expense',
              builder: (_, state) =>
                  ExpensePage(tripId: state.pathParameters['id']!),
            ),
          ],
        ),
      ],
    ),
  ],

  redirect: (_, state) {
    final user = FirebaseAuth.instance.currentUser;
    final loggingIn = state.uri.toString() == '/login';
    if (user == null && !loggingIn) return '/login';
    if (user != null && loggingIn) return '/';
    return null;
  },

  errorBuilder: (_, __) =>
      const Scaffold(body: Center(child: Text('404'))),
);

class _GoRouterRefresh extends ChangeNotifier {
  _GoRouterRefresh() {
    _sub = FirebaseAuth.instance
        .authStateChanges()
        .listen((_) => notifyListeners());
  }
  late final StreamSubscription<User?> _sub;
  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
