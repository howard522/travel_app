// lib/pages/home_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/auth_providers.dart';
import '../providers/trip_providers.dart';
import '../models/trip.dart';
import '../repositories/trip_repository.dart';

class HomePage extends ConsumerWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 監聽 FirebaseAuth 的使用者狀態
    final authStateAsync = ref.watch(authStateProvider);

    return authStateAsync.when(
      data: (user) {
        // 如果 user == null，表示使用者已登出，先顯示一個空白畫面／Loading，等 GoRouter 重導向到 /login
        if (user == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // user != null 時才顯示 HomePage 內容
        final myTrips = ref.watch(userTripsProvider);
        final invites = ref.watch(pendingTripInvitesProvider);
        final authRepo = ref.read(authRepoProvider);
        final tripRepo = ref.read(tripRepoProvider);

        return Scaffold(
          appBar: AppBar(
            title: const Text('My Trips'),
            actions: [
              IconButton(
                icon: const Icon(Icons.person),
                tooltip: '個人資料',
                onPressed: () => context.push('/profile'),
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: '登出',
                onPressed: () async {
                  // 執行登出
                  await authRepo.signOut();
                  // FirebaseAuth.authStateChanges() 會觸發 user = null，然後 GoRouter 的 redirect 會導到 /login
                },
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                // ===== 等待接受的邀請 區塊 =====
                invites.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text('邀請讀取失敗：$e'),
                  ),
                  data: (list) {
                    if (list.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            '待接受邀請',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        for (final t in list)
                          ListTile(
                            title: Text(t.title),
                            subtitle: Text(
                              DateFormat('yyyy-MM-dd HH:mm')
                                  .format(t.startTime.toLocal()),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 接受邀請
                                ElevatedButton(
                                  onPressed: () =>
                                      tripRepo.acceptInvite(t.id, user.uid, user.email!),
                                  child: const Text('接受'),
                                ),
                                const SizedBox(width: 8),
                                // 拒絕邀請
                                OutlinedButton(
                                  onPressed: () =>
                                      tripRepo.declineInvite(t.id, user.email!),
                                  child: const Text('拒絕'),
                                ),
                              ],
                            ),
                          ),
                        const Divider(height: 1),
                      ],
                    );
                  },
                ),

                // ===== 我的行程 區塊 =====
                Expanded(
                  child: myTrips.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text(e.toString())),
                    data: (list) {
                      if (list.isEmpty) {
                        return const Center(child: Text('No trip yet'));
                      }
                      return ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (_, i) => _TripTile(trip: list[i]),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showNewTripDialog(context, ref),
            child: const Icon(Icons.add),
          ),
        );
      },
      loading: () {
        // 在 authStateProvider 正在載入時顯示 Loading
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
      error: (e, _) {
        // 在監聽 authStateProvider 過程若有錯誤，顯示錯誤訊息
        return Scaffold(
          body: Center(child: Text('Error: $e')),
        );
      },
    );
  }

  /// 新增 Trip Dialog：讓使用者輸入標題、開始時間、天數 (1~365)
  Future<void> _showNewTripDialog(BuildContext context, WidgetRef ref) async {
    final titleCtrl = TextEditingController();
    DateTime startAt = DateTime.now();
    final daysCtrl = TextEditingController(text: '1');
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('New Trip'),
        content: StatefulBuilder(
          builder: (ctx, setState) {
            return Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 行程標題
                  TextFormField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Trip title',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return '請輸入行程標題';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // 開始時間選擇
                  ListTile(
                    title: Text(
                      'Start: ${DateFormat('yyyy-MM-dd HH:mm').format(startAt)}',
                    ),
                    trailing: const Icon(Icons.edit_calendar_outlined),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: startAt,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(startAt),
                        );
                        if (time != null) {
                          startAt = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                          (ctx as Element).markNeedsBuild();
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  // 天數輸入 (1~365)
                  TextFormField(
                    controller: daysCtrl,
                    decoration: const InputDecoration(
                      labelText: '天數 (1~365)',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return '請輸入天數';
                      }
                      final parsed = int.tryParse(v.trim());
                      if (parsed == null) {
                        return '請輸入有效整數';
                      }
                      if (parsed < 1 || parsed > 365) {
                        return '天數範圍必須在 1~365';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(dialogCtx, true);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final title = titleCtrl.text.trim();
    final daysInput = daysCtrl.text.trim();
    final parsedDays = int.parse(daysInput);

    // 由 authStateProvider 取得目前 user
    final user = ref.read(authStateProvider).value!;
    final repo = ref.read(tripRepoProvider);

    // 計算 endDate：startAt 當天算第 1 天
    final endDate = DateTime(startAt.year, startAt.month, startAt.day)
        .add(Duration(days: parsedDays - 1));

    await repo.addTrip(
      Trip(
        id:        '_tmp',
        title:     title,
        members:   [user.uid],
        invites:   [],
        startTime: startAt,
        endDate:   endDate,
      ),
    );
  }
}

/// 列出單一 Trip 的列表項目
class _TripTile extends StatelessWidget {
  const _TripTile({Key? key, required this.trip}) : super(key: key);
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(trip.title),
      subtitle: Text(
        DateFormat('yyyy-MM-dd HH:mm').format(trip.startTime.toLocal()),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/trip/${trip.id}'),
    );
  }
}
