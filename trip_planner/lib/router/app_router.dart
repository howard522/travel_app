import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/trip.dart';
import '../pages/sign_in_page.dart';
import '../pages/home_page.dart';
import '../pages/trip_page.dart';
import '../pages/expense_page.dart';

/* ───────────────────────────────── router ─────────────────────────────── */

final appRouter = GoRouter(
  refreshListenable: _GoRouterRefresh(),
  routes: [
    GoRoute(
      path: '/login',
      builder: (_, __) => const SignInPage(),
    ),

    GoRoute(
      path: '/',
      builder: (_, __) => const HomePage(),
      routes: [
        GoRoute(
          path: 'trip/:id',
          builder: (_, state) {
            final id   = state.pathParameters['id']!;
            final trip = state.extra as Trip?;   // extra 可能為 null
            return TripPage(tripId: id, trip: trip);
          },
          routes: [
            
            GoRoute(
              path: 'expense',
              builder: (_, state) => ExpensePage(
                tripId: state.pathParameters['id']!,   // 共用上一層的 :id
              ),
            ),
          ],
        ),
      ],
    ),
  ],

  /* -------------- 自動導向（登入 / 未登入） ----------------- */
  redirect: (_, state) {
    final user      = FirebaseAuth.instance.currentUser;
    final loggingIn = state.uri.path == '/login';
    if (user == null && !loggingIn) return '/login';
    if (user != null && loggingIn)  return '/';
    return null;
  },

  errorBuilder: (_, __) =>
      const Scaffold(body: Center(child: Text('404'))),
);

/* ───────────────────────────────── listener ───────────────────────────── */

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
