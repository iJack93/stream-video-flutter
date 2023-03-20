import 'package:flutter/services.dart';

class StreamVideoMethodChannel {
  const StreamVideoMethodChannel({
    MethodChannel methodChannel = const MethodChannel('stream_video'),
  }) : _methodChannel = methodChannel;

  /// The method channel used to interact with the native platform.
  final MethodChannel _methodChannel;

  /// Obtain the Device Push Token VoIp.
  Future<String?> getDevicePushTokenVoIP() async {
    return _methodChannel.invokeMethod<String>('getDevicePushTokenVoIP');
  }
}
