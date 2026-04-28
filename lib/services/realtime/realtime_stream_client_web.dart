// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;

import 'realtime_stream_client_base.dart';

class _WebRealtimeStreamClient implements RealtimeStreamClient {
  @override
  Stream<String> connect(String url) {
    late html.EventSource eventSource;
    late StreamController<String> controller;

    controller = StreamController<String>.broadcast(
      onListen: () {
        eventSource = html.EventSource(url);
        eventSource.onMessage.listen((event) {
          controller.add(event.data ?? '');
        });
        eventSource.onError.listen((_) {
          if (!controller.isClosed) {
            controller.add('__stream_error__');
          }
        });
      },
      onCancel: () {
        eventSource.close();
      },
    );

    return controller.stream;
  }
}

RealtimeStreamClient createRealtimeStreamClientImpl() {
  return _WebRealtimeStreamClient();
}
