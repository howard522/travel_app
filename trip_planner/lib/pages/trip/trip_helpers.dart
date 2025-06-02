import '../../models/place.dart';
import '../../models/trip.dart';

/// computeDepartureTimes: 計算單日各景點的出發時間列表
List<DateTime> computeDepartureTimes(
  List<Place> dayPlaces,
  Trip trip,
  DateTime day,
  Map<String, String> durationsMap,
) {
  if (dayPlaces.isEmpty) return [];

  // 判斷是否為行程第一天
  final firstDayOfTrip = DateTime(
      trip.startTime.year, trip.startTime.month, trip.startTime.day);
  final isFirstDay = day == firstDayOfTrip;

  DateTime displayStartTime;
  if (isFirstDay) {
    displayStartTime = trip.startTime;
  } else {
    displayStartTime = DateTime(
      day.year,
      day.month,
      day.day,
      trip.startTime.hour,
      trip.startTime.minute,
    );
  }

  final departureTimes = <DateTime>[displayStartTime];
  for (var i = 0; i < dayPlaces.length - 1; i++) {
    final nextPlaceId = dayPlaces[i + 1].id;
    final durMin = int.tryParse(durationsMap[nextPlaceId] ?? '0') ?? 0;
    final leaveTime = departureTimes.last
        .add(Duration(minutes: durMin))
        .add(Duration(hours: dayPlaces[i].stayHours));
    departureTimes.add(leaveTime);
  }
  return departureTimes;
}
