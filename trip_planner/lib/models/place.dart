/// 行程中的景點
class Place {
  final String id;
  final String name;
  final String? address;
  final double lat;
  final double lng;
  final int order;
  final int stayHours;
  final String note;

  Place({
    required this.id,
    required this.name,
    this.address,
    required this.lat,
    required this.lng,
    required this.order,
    required this.stayHours,
    required this.note,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'lat': lat,
        'lng': lng,
        'order': order,
        'stayHours': stayHours,
        'note': note,
      };

  factory Place.fromJson(Map<String, dynamic> json) => Place(
        id: json['id'] as String,
        name: json['name'] as String,
        address: json['address'] as String?,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        order: json['order'] as int,
        stayHours: json['stayHours'] as int,
        note: json['note'] as String,
      );
}
