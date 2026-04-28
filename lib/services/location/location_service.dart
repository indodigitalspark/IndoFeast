import 'location_service_stub.dart'
    if (dart.library.html) 'location_service_web.dart';

typedef GeoPoint = ({double latitude, double longitude});

Future<GeoPoint?> getCurrentGeoPoint() => getCurrentGeoPointImpl();
