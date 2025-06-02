// // lib/pages/trip_page.dart

// import 'dart:async';
// import 'dart:math';

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:go_router/go_router.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:flutter_polyline_points/flutter_polyline_points.dart';
// import 'package:reorderables/reorderables.dart';
// import 'package:intl/intl.dart';

// import '../models/place.dart';
// import '../models/segment_info.dart';
// import '../models/trip.dart';
// import '../providers/place_providers.dart';
// import '../providers/trip_providers.dart';
// import '../repositories/trip_repository.dart';
// import '../services/place_search_service.dart';
// import '../services/schedule_service.dart';
// import 'add_invite_dialog.dart';

// /// TripPage (多天行程) 完整修正版：
// /// - 只有一個 Scaffold，AppBar + TabBar + TabBarView + endDrawer
// /// - 點右上角 IconButton 能正確開啟當前分頁日期的「側邊面板」
// /// - 切換分頁後，側邊面板內容自動重建
// class TripPage extends ConsumerStatefulWidget {
//   const TripPage({Key? key, required this.tripId}) : super(key: key);
//   final String tripId;

//   @override
//   ConsumerState<TripPage> createState() => _TripPageState();
// }

// class _TripPageState extends ConsumerState<TripPage>
//     with TickerProviderStateMixin {
//   final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
//   GoogleMapController? _mapController;

//   Set<Polyline> _polylines = {};
//   Map<String, String> _durationsMap = {}; // 存放 place.id 對應到該段路程(分鐘)
//   List<String> _modes = []; // 當天各段交通模式

//   TabController? _tabController;

//   @override
//   void dispose() {
//     _mapController?.dispose();
//     _tabController?.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final tripRepo = ref.read(tripRepoProvider);

//     // 監聽單一 Trip
//     return StreamBuilder<Trip>(
//       stream: tripRepo.watchTrip(widget.tripId),
//       builder: (context, tripSnapshot) {
//         if (tripSnapshot.connectionState == ConnectionState.waiting) {
//           return const Scaffold(
//             body: Center(child: CircularProgressIndicator()),
//           );
//         }
//         if (tripSnapshot.hasError || !tripSnapshot.hasData) {
//           return Scaffold(
//             body: Center(
//               child: Text(
//                 'Error loading trip: ${tripSnapshot.error ?? 'No data'}',
//               ),
//             ),
//           );
//         }

//         final trip = tripSnapshot.data!;
//         // 計算「從 startDate 到 endDate」的所有日期（純日期，去掉時分）
//         final startDate = DateTime(
//           trip.startTime.year,
//           trip.startTime.month,
//           trip.startTime.day,
//         );
//         final endDate = DateTime(
//           trip.endDate.year,
//           trip.endDate.month,
//           trip.endDate.day,
//         );
//         final List<DateTime> tripDates = [];
//         for (
//           var d = startDate;
//           !d.isAfter(endDate);
//           d = d.add(const Duration(days: 1))
//         ) {
//           tripDates.add(d);
//         }

//         // 初始化或更新 TabController
//         if (_tabController == null ||
//             _tabController!.length != tripDates.length) {
//           _tabController?.dispose();
//           _tabController = TabController(length: tripDates.length, vsync: this);
//           _tabController!.addListener(() {
//             if (_tabController!.indexIsChanging) {
//               // 切換分頁時，清空前一次分頁的路線資訊
//               setState(() {
//                 _polylines = {};
//                 _durationsMap = {};
//                 _modes = [];
//               });
//             }
//           });
//         }

//         // 監聽該 Trip 底下所有 Place
//         final placesAsync = ref.watch(placesOfTripProvider(widget.tripId));
//         // 監聽該 Trip 的待接受邀請列表
//         final pendingAsync = ref.watch(pendingInvitesProvider(widget.tripId));

//         return Scaffold(
//           key: _scaffoldKey,
//           appBar: AppBar(
//             title: Hero(
//               tag: 'trip_${trip.id}',
//               child: Material(
//                 type: MaterialType.transparency,
//                 child: Text(
//                   trip.title,
//                   style: Theme.of(context).textTheme.titleLarge,
//                 ),
//               ),
//             ),
//             bottom: TabBar(
//               controller: _tabController,
//               isScrollable: true,
//               tabs: [
//                 for (final date in tripDates)
//                   Tab(text: DateFormat('MM/dd').format(date)),
//               ],
//             ),
//             actions: [
//               IconButton(
//                 icon: const Icon(Icons.menu),
//                 tooltip: '操作面板',
//                 onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
//               ),
//             ],
//           ),
//           // 側邊抽屜：依據當前分頁 index，顯示該日行程的側邊面板
//           endDrawer: Drawer(
//             child: SafeArea(
//               child: Padding(
//                 padding: const EdgeInsets.all(8),
//                 child: placesAsync.when(
//                   loading:
//                       () => const Center(child: CircularProgressIndicator()),
//                   error:
//                       (e, _) => Center(child: Text('Error loading places: $e')),
//                   data: (allPlaces) {
//                     // 取出當前分頁的日期
//                     final currentIndex = _tabController!.index;
//                     final day = tripDates[currentIndex];
//                     // 過濾出屬於 day 的所有 Place
//                     final dayPlaces =
//                         allPlaces
//                             .where(
//                               (p) =>
//                                   p.date.year == day.year &&
//                                   p.date.month == day.month &&
//                                   p.date.day == day.day,
//                             )
//                             .toList()
//                           ..sort((a, b) => a.order.compareTo(b.order));

//                     return _buildSidePanel(
//                       context,
//                       trip,
//                       dayPlaces,
//                       pendingAsync,
//                       tripRepo,
//                       day,
//                       currentIndex,
//                     );
//                   },
//                 ),
//               ),
//             ),
//           ),
//           // 主畫面：每個分頁顯示該日 GoogleMap
//           body: TabBarView(
//             controller: _tabController,
//             children: [
//               for (int i = 0; i < tripDates.length; i++)
//                 _buildMapForDay(
//                   trip,
//                   tripDates[i],
//                   ref.watch(placesOfTripProvider(widget.tripId)),
//                 ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   /// 每日的 Google Map 畫面，只顯示地圖與該日 Marker、Polyline
//   Widget _buildMapForDay(
//     Trip trip,
//     DateTime day,
//     AsyncValue<List<Place>> placesAsync,
//   ) {
//     return placesAsync.when(
//       loading: () => const Center(child: CircularProgressIndicator()),
//       error: (e, _) => Center(child: Text('Error loading places: $e')),
//       data: (allPlaces) {
//         // 過濾出當天的 places
//         final dayPlaces =
//             allPlaces
//                 .where(
//                   (p) =>
//                       p.date.year == day.year &&
//                       p.date.month == day.month &&
//                       p.date.day == day.day,
//                 )
//                 .toList()
//               ..sort((a, b) => a.order.compareTo(b.order));

//         // Map Marker 與自動拉到合適範圍
//         final markers = _buildMarkers(dayPlaces);
//         _fitBounds(markers);

//         return GoogleMap(
//           initialCameraPosition: const CameraPosition(
//             target: LatLng(23.5, 121),
//             zoom: 6.5,
//           ),
//           markers: markers,
//           polylines: _polylines,
//           onMapCreated: (c) => _mapController = c,
//           myLocationButtonEnabled: false,
//           onTap: (pos) => _handleMapTap(context, trip, pos, day),
//         );
//       },
//     );
//   }

//   /// 側邊面板：顯示當日行程開始時間、景點列表（可排序、刪除、停留時間）、算路方式 + 路線重算按鈕、邀請列表、新增景點、帳單、聊天室
//   Widget _buildSidePanel(
//     BuildContext context,
//     Trip trip,
//     List<Place> dayPlaces,
//     AsyncValue<List<String>> pendingAsync,
//     TripRepository repo,
//     DateTime day,
//     int dayIndex,
//   ) {
//     final isFirstDay = (dayIndex == 0);
//     final baseTime = trip.startTime;
//     final defaultDayStartTime = DateTime(
//       day.year,
//       day.month,
//       day.day,
//       baseTime.hour,
//       baseTime.minute,
//     );
//     DateTime displayStartTime = defaultDayStartTime;
//     if (isFirstDay) {
//       displayStartTime = trip.startTime;
//     }

//     // 計算 ETA / ETD
//     final departureTimes = <DateTime>[displayStartTime];
//     for (var i = 0; i < dayPlaces.length - 1; i++) {
//       final durMin =
//           int.tryParse(_durationsMap[dayPlaces[i + 1].id] ?? '0') ?? 0;
//       departureTimes.add(
//         departureTimes.last
//             .add(Duration(minutes: durMin))
//             .add(Duration(hours: dayPlaces[i].stayHours)),
//       );
//     }

//     // 行程開始時間 Tile（只有第一天才可編輯）
//     final startTile = ListTile(
//       title: const Text('行程開始時間'),
//       subtitle: Text(DateFormat('yyyy-MM-dd HH:mm').format(displayStartTime)),
//       trailing:
//           isFirstDay
//               ? IconButton(
//                 icon: const Icon(Icons.edit),
//                 onPressed: _pickStartTime,
//               )
//               : null,
//     );

//     return Column(
//       children: [
//         startTile,
//         const Divider(),
//         // 當日景點列表，可拖曳排序
//         Expanded(
//           child: ReorderableColumn(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             onReorder: (oldIdx, newIdx) async {
//               final list = [...dayPlaces];
//               final item = list.removeAt(oldIdx);
//               list.insert(newIdx, item);
//               await repo.reorderPlaces(widget.tripId, list);
//             },
//             children: [
//               for (var i = 0; i < dayPlaces.length; i++)
//                 Card(
//                   key: ValueKey(dayPlaces[i].id),
//                   margin: const EdgeInsets.symmetric(vertical: 4),
//                   child: Padding(
//                     padding: const EdgeInsets.all(8),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           '${i + 1}. ${dayPlaces[i].name}',
//                           style: const TextStyle(fontSize: 16),
//                         ),
//                         const SizedBox(height: 4),
//                         Text(
//                           '抵達: ${DateFormat('HH:mm').format(departureTimes[i])}',
//                         ),
//                         Row(
//                           children: [
//                             const Text('停留 (小時):'),
//                             const SizedBox(width: 8),
//                             DropdownButton<int>(
//                               value: dayPlaces[i].stayHours,
//                               items:
//                                   List.generate(12, (j) => j + 1)
//                                       .map(
//                                         (h) => DropdownMenuItem(
//                                           value: h,
//                                           child: Text('$h'),
//                                         ),
//                                       )
//                                       .toList(),
//                               onChanged: (h) async {
//                                 if (h == null) return;
//                                 await repo.updatePlace(
//                                   widget.tripId,
//                                   dayPlaces[i].id,
//                                   {'stayHours': h},
//                                 );
//                               },
//                             ),
//                           ],
//                         ),
//                         Text(
//                           '離開: ${DateFormat('HH:mm').format(departureTimes[i].add(Duration(hours: dayPlaces[i].stayHours)))}',
//                         ),
//                         Align(
//                           alignment: Alignment.topRight,
//                           child: IconButton(
//                             icon: const Icon(Icons.delete_outline),
//                             onPressed:
//                                 () => repo.deletePlace(
//                                   widget.tripId,
//                                   dayPlaces[i].id,
//                                 ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//             ],
//           ),
//         ),
//         if (dayPlaces.length > 1) ...[
//           const Divider(),
//           const Padding(
//             padding: EdgeInsets.symmetric(vertical: 8),
//             child: Text('各路段交通方式'),
//           ),
//           for (var i = 0; i < dayPlaces.length - 1; i++)
//             Row(
//               children: [
//                 Expanded(
//                   child: Text(
//                     '段 ${i + 1}: ${dayPlaces[i].name} → ${dayPlaces[i + 1].name}',
//                   ),
//                 ),
//                 DropdownButton<String>(
//                   value: _modes[i],
//                   items: const [
//                     DropdownMenuItem(value: 'driving', child: Text('開車')),
//                     DropdownMenuItem(value: 'walking', child: Text('走路')),
//                     DropdownMenuItem(value: 'bus', child: Text('公車')),
//                     DropdownMenuItem(value: 'subway', child: Text('捷運')),
//                   ],
//                   onChanged: (v) => setState(() => _modes[i] = v!),
//                 ),
//               ],
//             ),
//           ElevatedButton.icon(
//             onPressed: () => _recalculateRouteWithModes(dayPlaces),
//             icon: const Icon(Icons.sync),
//             label: const Text('重算路線'),
//           ),
//         ],
//         const Divider(),
//         // 顯示待接受邀請 (全 Trip)
//         pendingAsync.when(
//           data:
//               (invites) =>
//                   invites.isEmpty
//                       ? const SizedBox.shrink()
//                       : Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: invites.map((e) => Text('• $e')).toList(),
//                       ),
//           loading: () => const Center(child: CircularProgressIndicator()),
//           error: (e, _) => Text('Error: $e'),
//         ),
//         const Divider(),
//         OverflowBar(
//           spacing: 8,
//           overflowSpacing: 8,
//           alignment: MainAxisAlignment.center,
//           children: [
//             ElevatedButton.icon(
//               onPressed: () => _addPlaceDialog(context, repo, day),
//               icon: const Icon(Icons.add_location_alt_outlined),
//               label: const Text('新增景點'),
//             ),
//             OutlinedButton.icon(
//               onPressed:
//                   () => showDialog(
//                     context: context,
//                     builder: (_) => AddInviteDialog(tripId: widget.tripId),
//                   ),
//               icon: const Icon(Icons.mail_outlined),
//               label: const Text('邀請成員'),
//             ),
//             ElevatedButton.icon(
//               onPressed: () => context.push('/trip/${widget.tripId}/expense'),
//               icon: const Icon(Icons.receipt_long),
//               label: const Text('帳單'),
//             ),
//             OutlinedButton.icon(
//               onPressed: () => context.push('/trip/${widget.tripId}/chat'),
//               icon: const Icon(Icons.chat_bubble_outline),
//               label: const Text('聊天室'),
//             ),
//           ],
//         ),
//       ],
//     );
//   }

//   /// 建立 Marker 列表
//   Set<Marker> _buildMarkers(List<Place> places) => {
//     for (var i = 0; i < places.length; i++)
//       Marker(
//         markerId: MarkerId(places[i].id),
//         position: LatLng(places[i].lat, places[i].lng),
//         infoWindow: InfoWindow(title: '${i + 1}. ${places[i].name}'),
//       ),
//   };

//   /// 地圖自動調整至包含所有 Marker
//   void _fitBounds(Set<Marker> markers) {
//     if (_mapController == null || markers.isEmpty) return;
//     final lats = markers.map((m) => m.position.latitude);
//     final lngs = markers.map((m) => m.position.longitude);
//     final sw = LatLng(lats.reduce(min), lngs.reduce(min));
//     final ne = LatLng(lats.reduce(max), lngs.reduce(max));
//     _mapController!.animateCamera(
//       CameraUpdate.newLatLngBounds(
//         LatLngBounds(southwest: sw, northeast: ne),
//         48,
//       ),
//     );
//   }

//   /// 只在第一天可修改 Trip.startTime
//   Future<void> _pickStartTime() async {
//     final tripDoc =
//         await ref.read(tripRepoProvider).watchTrip(widget.tripId).first;
//     final current = tripDoc.startTime;
//     final date = await showDatePicker(
//       context: context,
//       initialDate: current,
//       firstDate: DateTime(2000),
//       lastDate: DateTime(2100),
//     );
//     if (date == null) return;
//     final time = await showTimePicker(
//       context: context,
//       initialTime: TimeOfDay.fromDateTime(current),
//     );
//     if (time == null) return;
//     final newStart = DateTime(
//       date.year,
//       date.month,
//       date.day,
//       time.hour,
//       time.minute,
//     );
//     await ref.read(tripRepoProvider).updateTrip(widget.tripId, {
//       'startTime': newStart,
//     });
//   }

//   /// 地圖點擊：新增當日自訂景點
//   Future<void> _handleMapTap(
//     BuildContext context,
//     Trip trip,
//     LatLng pos,
//     DateTime day,
//   ) async {
//     final nameCtrl = TextEditingController();
//     final ok = await showModalBottomSheet<bool>(
//       context: context,
//       isScrollControlled: true,
//       builder:
//           (_) => Padding(
//             padding: EdgeInsets.only(
//               bottom: MediaQuery.of(context).viewInsets.bottom,
//             ),
//             child: Wrap(
//               children: [
//                 const ListTile(title: Text('新增自訂景點')),
//                 Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 16),
//                   child: Column(
//                     children: [
//                       TextField(
//                         controller: nameCtrl,
//                         decoration: const InputDecoration(labelText: '景點名稱'),
//                       ),
//                       const SizedBox(height: 12),
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.end,
//                         children: [
//                           TextButton(
//                             onPressed: () => Navigator.pop(context, false),
//                             child: const Text('取消'),
//                           ),
//                           ElevatedButton(
//                             onPressed: () => Navigator.pop(context, true),
//                             child: const Text('加入景點'),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//     );
//     if (ok == true && nameCtrl.text.trim().isNotEmpty) {
//       await ref
//           .read(tripRepoProvider)
//           .addPlace(
//             widget.tripId,
//             Place(
//               id: '_tmp',
//               name: nameCtrl.text.trim(),
//               lat: pos.latitude,
//               lng: pos.longitude,
//               order: DateTime.now().millisecondsSinceEpoch,
//               stayHours: 1,
//               note: '',
//               date: day,
//             ),
//           );
//     }
//   }

//   /// 重新計算當日路線
//   Future<void> _recalculateRouteWithModes(List<Place> dayPlaces) async {
//     final key = const String.fromEnvironment('PLACES_API_KEY');
//     final service = ScheduleService(key);
//     final segments = <SegmentInfo>[];

//     for (var i = 0; i < dayPlaces.length - 1; i++) {
//       segments.add(
//         await service.getSegmentInfo(
//           '${dayPlaces[i].lat},${dayPlaces[i].lng}',
//           '${dayPlaces[i + 1].lat},${dayPlaces[i + 1].lng}',
//           _modes[i],
//         ),
//       );
//     }

//     final allPoints = <LatLng>[];
//     final decoder = PolylinePoints();
//     for (final seg in segments) {
//       allPoints.addAll(
//         decoder
//             .decodePolyline(seg.polyline)
//             .map((p) => LatLng(p.latitude, p.longitude)),
//       );
//     }

//     setState(() {
//       _polylines = {
//         Polyline(
//           polylineId: const PolylineId('route'),
//           points: allPoints,
//           width: 4,
//         ),
//       };
//       _durationsMap = {
//         for (var i = 0; i < segments.length; i++)
//           dayPlaces[i + 1].id: (segments[i].duration / 60).round().toString(),
//       };
//     });
//   }

//   /// 新增當日搜尋景點
//   Future<void> _addPlaceDialog(
//     BuildContext context,
//     TripRepository repo,
//     DateTime day,
//   ) async {
//     final query = TextEditingController();
//     List<PlaceSuggestion>? results;

//     final picked = await showDialog<PlaceSuggestion>(
//       context: context,
//       builder:
//           (ctx) => StatefulBuilder(
//             builder:
//                 (_, setState) => AlertDialog(
//                   title: const Text('搜尋景點'),
//                   content: Column(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       TextField(
//                         controller: query,
//                         decoration: const InputDecoration(hintText: '輸入關鍵字'),
//                       ),
//                       const SizedBox(height: 8),
//                       ElevatedButton(
//                         onPressed: () async {
//                           final key = const String.fromEnvironment(
//                             'PLACES_API_KEY',
//                           );
//                           if (key.isEmpty) {
//                             ScaffoldMessenger.of(context).showSnackBar(
//                               const SnackBar(
//                                 content: Text('請設定 PLACES_API_KEY'),
//                               ),
//                             );
//                             return;
//                           }
//                           results = await PlaceSearchService(
//                             key,
//                           ).search(query.text);
//                           setState(() {});
//                         },
//                         child: const Text('搜尋'),
//                       ),
//                       if (results != null)
//                         SizedBox(
//                           height: 240,
//                           width: 300,
//                           child: ListView.builder(
//                             itemCount: results!.length,
//                             itemBuilder:
//                                 (_, i) => ListTile(
//                                   title: Text(results![i].name),
//                                   onTap: () => Navigator.pop(ctx, results![i]),
//                                 ),
//                           ),
//                         ),
//                     ],
//                   ),
//                 ),
//           ),
//     );

//     if (picked != null) {
//       await repo.addPlace(
//         widget.tripId,
//         Place(
//           id: '_tmp',
//           name: picked.name,
//           lat: picked.lat,
//           lng: picked.lng,
//           order: DateTime.now().millisecondsSinceEpoch,
//           stayHours: 1,
//           note: '',
//           date: day,
//         ),
//       );
//     }
//   }
// }
