class Place {
  final String id;
  final String name;
  final double lat, lng;
  final int order;
  final int stayHours;
  final String note;

  Place({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.order,
    required this.stayHours,
    required this.note,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lat': lat,
        'lng': lng,
        'order': order,
        'stayHours': stayHours,
        'note': note,
      };

  factory Place.fromJson(Map<String, dynamic> json) => Place(
        id: json['id'],
        name: json['name'],
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        order: json['order'],
        stayHours: json['stayHours'],
        note: json['note'],
      );
}
