/// The type of call to be made.
///
/// The default type is [StreamCallType()] which is a normal call.
///
/// [StreamCallType.liveStream()] is used for live streaming.
/// [StreamCallType.audioRoom()] is used for audio rooms.
/// [StreamCallType.development()] is used for development.
///
/// You can also create a custom type using [StreamCallType.custom].
/// ```dart
/// StreamCallType.custom('custom_type');
/// ```
class StreamCallType {
  const StreamCallType._(this.value);

  final String value;

  factory StreamCallType() => const StreamCallType._('default');
  factory StreamCallType.liveStream() => const StreamCallType._('livestream');
  factory StreamCallType.development() => const StreamCallType._('development');
  factory StreamCallType.audioRoom() => const StreamCallType._('audio_room');
  factory StreamCallType.custom(String customType) =>
      StreamCallType._(customType);

  factory StreamCallType.fromString(String type) {
    switch (type) {
      case 'default':
        return StreamCallType();
      case 'livestream':
        return StreamCallType.liveStream();
      case 'development':
        return StreamCallType.development();
      case 'audio_room':
        return StreamCallType.audioRoom();
      default:
        return StreamCallType.custom(type);
    }
  }
}
