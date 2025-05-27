import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../pages/sign_in_page.dart';
import '../pages/home_page.dart';
import '../pages/trip_page.dart';
import '../pages/expense_page.dart';

final appRouter = GoRouter(
  refreshListenable: _GoRouterRefresh(),   // 監聽登入狀態
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const SignInPage()),
    GoRoute(
      path: '/',
      builder: (_, __) => const HomePage(),
      routes: [
        GoRoute(
          path: 'trip/:id',
          builder: (_, s) => TripPage(tripId: s.pathParameters['id']!),
          routes: [
            GoRoute(
              path: 'expense',
              builder: (_, s) =>
                  ExpensePage(tripId: s.pathParameters['id']!),
            ),
          ],
        ),
      ],
    ),
  ],

  /// 未登入 → /login；已登入但在 /login → /
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

/* ───────── Firebase authStateChanges() → Listenable ───────── */

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
