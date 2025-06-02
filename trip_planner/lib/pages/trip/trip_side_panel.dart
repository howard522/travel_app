import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/trip.dart';
import '../../models/place.dart';
import '../../providers/trip_providers.dart';
import '../../repositories/trip_repository.dart';
import '../add_invite_dialog.dart';
import 'trip_place_list.dart';
import 'trip_route_controls.dart';
import 'trip_helpers.dart';
import '../../services/place_search_service.dart';

/// TripSidePanel: 側邊抽屜內容
///
/// 1. 行程開始時間 Tile
/// 2. 當日景點列表（可排序、刪除、停留時間）
/// 3. 交通模式選擇 + 重算路線按鈕（只有當日景點 > 1 才顯示）
/// 4. 待接受邀請列表
/// 5. 動作按鈕區：新增景點、邀請、帳單、聊天室
class TripSidePanel extends ConsumerStatefulWidget {
  final Trip trip;
  final List<DateTime> tripDates;
  final AsyncValue<List<Place>> placesAsync;
  final AsyncValue<List<String>> pendingInvitesAsync;
  final TabController tabController;

  const TripSidePanel({
    Key? key,
    required this.trip,
    required this.tripDates,
    required this.placesAsync,
    required this.pendingInvitesAsync,
    required this.tabController,
  }) : super(key: key);

  @override
  ConsumerState<TripSidePanel> createState() => _TripSidePanelState();
}

class _TripSidePanelState extends ConsumerState<TripSidePanel> {
  // 我們只在 data 分支裡去決定 _modes，不要在外面先給空列表
  List<String> _modes = [];
  Map<String, String> _durationsMap = {};

  @override
  void didUpdateWidget(covariant TripSidePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 當切換 tab (切換日期) 時，如果 placesAsync 已經有 data，再決定要不要重置 _modes
    final idx = widget.tabController.index;
    widget.placesAsync.whenData((allPlaces) {
      final day = widget.tripDates[idx];
      final dayPlaces = allPlaces.where((p) =>
          p.date.year == day.year &&
          p.date.month == day.month &&
          p.date.day == day.day).toList()
        ..sort((a, b) => a.order.compareTo(b.order));

      // 如果景點數改變(具備>1個)，就初始化 _modes
      final needed = (dayPlaces.length - 1).clamp(0, dayPlaces.length);
      if (_modes.length != needed) {
        setState(() {
          _modes = List.filled(needed, 'driving');
          _durationsMap = {};
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tripRepo = ref.read(tripRepoProvider);
    final idx = widget.tabController.index;
    final day = widget.tripDates[idx];

    // 1. 行程開始時間 Tile
    final isFirstDay = idx == 0;
    final baseTime = widget.trip.startTime;
    DateTime displayStartTime = DateTime(
      day.year,
      day.month,
      day.day,
      baseTime.hour,
      baseTime.minute,
    );
    if (isFirstDay) {
      displayStartTime = widget.trip.startTime;
    }

    // 開始把整份側邊欄拆成一個可捲動的 ListView
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      children: [
        // --- (1) 行程開始時間 ---
        ListTile(
          title: const Text('行程開始時間'),
          subtitle: Text(DateFormat('yyyy-MM-dd HH:mm').format(displayStartTime)),
          trailing: isFirstDay
              ? IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () async {
                    // 編輯 startTime
                    final current = (await ref
                            .read(tripRepoProvider)
                            .watchTrip(widget.trip.id)
                            .first)
                        .startTime;
                    final date = await showDatePicker(
                      context: context,
                      initialDate: current,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (date == null) return;
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(current),
                    );
                    if (time == null) return;
                    final newStart = DateTime(date.year, date.month, date.day,
                        time.hour, time.minute);
                    await tripRepo.updateTrip(widget.trip.id, {'startTime': newStart});
                  },
                )
              : null,
        ),

        const Divider(),

        // --- (2) 當日景點列表 & TripPlaceList ---
        widget.placesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error loading places: $e')),
          data: (allPlaces) {
            // 只在 data 分支，真實取得所有 place
            final dayPlaces = allPlaces.where((p) =>
                p.date.year == day.year &&
                p.date.month == day.month &&
                p.date.day == day.day).toList()
              ..sort((a, b) => a.order.compareTo(b.order));

            // 每個景點的出發時間陣列
            final departureTimes = computeDepartureTimes(
              dayPlaces,
              widget.trip,
              day,
              _durationsMap,
            );

            return TripPlaceList(
              places: dayPlaces,
              departureTimes: departureTimes,
              onReorder: (oldIdx, newIdx) async {
                final list = List<Place>.from(dayPlaces);
                final item = list.removeAt(oldIdx);
                list.insert(newIdx, item);
                await tripRepo.reorderPlaces(widget.trip.id, list);
              },
              onDelete: (place) async {
                await tripRepo.deletePlace(widget.trip.id, place.id);
              },
              onStayHoursChanged: (place, newHours) async {
                await tripRepo.updatePlace(
                  widget.trip.id,
                  place.id,
                  {'stayHours': newHours},
                );
              },
            );
          },
        ),

        // --- (3) 交通模式 + 重算路線 (只在日景點 > 1 時顯示) ---
        widget.placesAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (allPlaces) {
            // 先取得當天的 dayPlaces
            final dayPlaces = allPlaces.where((p) =>
                p.date.year == day.year &&
                p.date.month == day.month &&
                p.date.day == day.day).toList()
              ..sort((a, b) => a.order.compareTo(b.order));

            // 只在景點數 >1 時顯示交通模式區塊
            if (dayPlaces.length <= 1) {
              return const SizedBox.shrink();
            }

            // 計算需要的 modes 長度 (dayPlaces.length - 1)
            final needed = (dayPlaces.length - 1);
            // 如果 _modes 長度不對，就用預設值補一份，不直接改 _modes`
            final modesForBuild = (_modes.length == needed)
                ? _modes
                : List<String>.filled(needed, 'driving');

            return Column(
              children: [
                const Divider(),
                TripRouteControls(
                  places: dayPlaces,
                  modes: modesForBuild,
                  onModeChanged: (index, newMode) {
                    // 當使用者真正選擇交通模式時，再更新 _modes
                    setState(() {
                      // 如果 _modes 目前長度不符合，就先補齊到 needed，再賦值
                      if (_modes.length != needed) {
                        _modes = List<String>.filled(needed, 'driving');
                      }
                     _modes[index] = newMode;
                    });
                  },
                  onRecalculate: () {
                    // Day 4 時再把地圖 GlobalKey 拿進來連結 recalcRoute()
                  },
                ),
              ],
            );
          },
        ),

        // --- (4) 待接受邀請列表 ---
        const Divider(),

        widget.pendingInvitesAsync.when(
          data: (invites) {
            if (invites.isEmpty) {
              return const SizedBox.shrink();
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: invites.map((email) => Text('• $email')).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),

        // --- (5) 動作按鈕區 ---
        const Divider(),

        OverflowBar(
          spacing: 8,
          overflowSpacing: 8,
          alignment: MainAxisAlignment.center,
          children: [
            // 新增景點
            ElevatedButton.icon(
              onPressed: () async {
                final query = TextEditingController();
                List<PlaceSuggestion>? results;
                final picked = await showDialog<PlaceSuggestion>(
                  context: context,
                  builder: (ctx) => StatefulBuilder(
                    builder: (_, setState) => AlertDialog(
                      title: const Text('搜尋景點'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: query,
                            decoration: const InputDecoration(hintText: '輸入關鍵字'),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () async {
                              final key = const String.fromEnvironment('PLACES_API_KEY');
                              if (key.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('請設定 PLACES_API_KEY')),
                                );
                                return;
                              }
                              results = await PlaceSearchService(key).search(query.text);
                              setState(() {});
                            },
                            child: const Text('搜尋'),
                          ),
                          if (results != null)
                            SizedBox(
                              height: 240,
                              width: 300,
                              child: ListView.builder(
                                itemCount: results!.length,
                                itemBuilder: (_, i) => ListTile(
                                  title: Text(results![i].name),
                                  onTap: () => Navigator.pop(ctx, results![i]),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );

                if (picked != null) {
                  await tripRepo.addPlace(
                    widget.trip.id,
                    Place(
                      id: '_tmp',
                      name: picked.name,
                      lat: picked.lat,
                      lng: picked.lng,
                      order: DateTime.now().millisecondsSinceEpoch,
                      stayHours: 1,
                      note: '',
                      date: day,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('新增景點'),
            ),

            // 邀請成員
            OutlinedButton.icon(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => AddInviteDialog(tripId: widget.trip.id),
              ),
              icon: const Icon(Icons.mail_outlined),
              label: const Text('邀請成員'),
            ),

            // 帳單
            ElevatedButton.icon(
              onPressed: () =>
                  GoRouter.of(context).push('/trip/${widget.trip.id}/expense'),
              icon: const Icon(Icons.receipt_long),
              label: const Text('帳單'),
            ),

            // 聊天室
            OutlinedButton.icon(
              onPressed: () =>
                  GoRouter.of(context).push('/trip/${widget.trip.id}/chat'),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('聊天室'),
            ),
          ],
        ),
      ],
    );
  }
}
