import 'realtime_stream_client_base.dart';

class _StubRealtimeStreamClient implements RealtimeStreamClient {
  @override
  Stream<String> connect(String url) => const Stream<String>.empty();
}

RealtimeStreamClient createRealtimeStreamClientImpl() {
  return _StubRealtimeStreamClient();
}
