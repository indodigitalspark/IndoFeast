import 'realtime_stream_client_base.dart';
import 'realtime_stream_client_stub.dart'
    if (dart.library.html) 'realtime_stream_client_web.dart';

RealtimeStreamClient createRealtimeStreamClient() {
  return createRealtimeStreamClientImpl();
}
