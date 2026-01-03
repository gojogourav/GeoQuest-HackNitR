class Discovery {
  final String imagePath;
  final double lat;
  final double lng;
  final Map<String, dynamic> plantData;

  Discovery({
    required this.imagePath,
    required this.lat,
    required this.lng,
    required this.plantData,
  });

  Map<String, dynamic> toJson() => {
    'imagePath': imagePath,
    'lat': lat,
    'lng': lng,
    'plantData': plantData,
  };

  static Discovery fromJson(Map<String, dynamic> json) {
    return Discovery(
      imagePath: json['imagePath'],
      lat: json['lat'],
      lng: json['lng'],
      plantData: Map<String, dynamic>.from(json['plantData']),
    );
  }
}
