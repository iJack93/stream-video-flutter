import 'dart:async';

import '../stream_video.dart';
import 'call_permission.dart';
import 'coordinator/coordinator_client.dart';
import 'coordinator/models/coordinator_events.dart';
import 'coordinator/models/coordinator_inputs.dart' as input;
import 'coordinator/models/coordinator_inputs.dart';
import 'coordinator/models/coordinator_models.dart';
import 'coordinator/open_api/coordinator_client_open_api.dart';
import 'errors/video_error_composer.dart';
import 'models/call_device.dart';
import 'models/call_reaction.dart';
import 'models/queried_calls.dart';
import 'shared_emitter.dart';
import 'state_emitter.dart';
import 'token/token_manager.dart';
import 'utils/none.dart';

/// The client responsible for handling config and maintaining calls
class StreamVideoImpl implements StreamVideo {
  /// Creates a new Stream Video client unassociated with the
  /// Stream Video singleton instance
  factory StreamVideoImpl(
    String apiKey, {
    required String coordinatorRpcUrl,
    required String coordinatorWsUrl,
    required int latencyMeasurementRounds,
  }) {
    return StreamVideoImpl._(
      apiKey,
      coordinatorRpcUrl: coordinatorRpcUrl,
      coordinatorWsUrl: coordinatorWsUrl,
      latencyMeasurementRounds: latencyMeasurementRounds,
    );
  }

  StreamVideoImpl._(
    this.apiKey, {
    required this.coordinatorRpcUrl,
    required this.coordinatorWsUrl,
    required this.latencyMeasurementRounds,
  }) {
    _client = buildCoordinatorClient(
      apiKey: apiKey,
      tokenManager: _tokenManager,
      rpcUrl: coordinatorRpcUrl,
      wsUrl: coordinatorWsUrl,
    );
  }

  final _logger = taggedLogger(tag: 'SV:Client');

  final String apiKey;
  final String coordinatorRpcUrl;
  final String coordinatorWsUrl;
  final int latencyMeasurementRounds;

  final _tokenManager = TokenManager();
  late final CoordinatorClient _client;
  PushNotificationManager? _pushNotificationManager;

  var _state = _StreamVideoState();

  StreamSubscription<CoordinatorEvent>? _eventSubscription;

  @override
  set pushNotificationManager(PushNotificationManager pushNotificationManager) {
    _pushNotificationManager = pushNotificationManager;
  }

  @override
  UserInfo? get currentUser => _state.currentUser.valueOrNull;

  @override
  SharedEmitter<CoordinatorEvent> get events => _client.events;

  @override
  void Function(CallCreated)? onCallCreated;

  /// Connects the [user] to the Stream Video service.
  @override
  Future<Result<None>> connectUser(
    UserInfo user, {
    Token? token,
    TokenProvider? provider,
  }) async {
    _logger.i(() => '[connectUser] user.id : ${user.id}');
    if (currentUser != null) {
      _logger.w(() => '[connectUser] rejected (already set): $currentUser');
      return Result.success(None());
    }
    _state.currentUser.value = user;
    await _tokenManager.setTokenOrProvider(
      user.id,
      token: token,
      provider: provider,
    );

    try {
      _eventSubscription = _client.events.listen((event) {
        _logger.v(() => '[onCoordWsEvent] event.type: ${event.runtimeType}');
        if (event is CoordinatorCallCreatedEvent) {
          final callCreated = CallCreated(
            callCid: StreamCallCid(cid: event.callCid),
            ringing: event.ringing,
            metadata: CallMetadata(
              details: event.details,
              info: event.info,
              users: event.users,
            ),
          );
          _logger.v(() => '[onCoordWsEvent] onCallCreated: $callCreated');
          onCallCreated?.call(callCreated);
        }
      });

      final result = await _client.onUserLogin(user);
      await _pushNotificationManager?.onUserLoggedIn();
      return result;
    } catch (e, stk) {
      _logger.e(() => '[connectUser] failed(${user.id}): $e');
      return Result.failure(VideoErrors.compose(e, stk));
    }
  }

  /// Disconnects the [user] from the Stream Video service.
  @override
  Future<Result<None>> disconnectUser() async {
    _logger.i(() => '[disconnectUser] currentUser.id: ${currentUser?.id}');
    if (currentUser == null) {
      _logger.w(() => '[disconnectUser] rejected (no user): $currentUser');
      return Result.success(None());
    }
    try {
      await _client.onUserLogout();
      await _eventSubscription?.cancel();
      _eventSubscription = null;
      _tokenManager.reset();

      // Resetting the state.
      await _state.close();
      _state = _StreamVideoState();
      return Result.success(None());
    } catch (e, stk) {
      _logger.e(() => '[disconnectUser] failed: $e');
      return Result.failure(VideoErrors.compose(e, stk));
    }
  }

  @override
  Future<Result<CallCreated>> createCall({
    required StreamCallCid cid,
    List<String> participantIds = const [],
    bool ringing = false,
  }) async {
    _logger.d(
      () => '[createCall] cid: $cid, ringing: $ringing, '
          'participantIds: $participantIds',
    );

    final currentUserId = _state.currentUser.value?.id;
    if (currentUserId == null) {
      _logger.e(() => '[createCall] failed (no userId)');
      return Result.error('[createCall] failed; no user_id found');
    }

    final response = await _client.createCall(
      input.CreateCallInput(
        callCid: cid,
        ringing: ringing,
        members: participantIds.map((id) {
          return input.MemberInput(
            userId: id,
            role: 'admin',
          );
        }),
      ),
    );

    return response.fold(
      success: (it) {
        _logger.v(() => '[createCall] completed: ${it.data}');
        return it;
      },
      failure: (it) {
        _logger.e(() => '[createCall] failed: ${it.error}');
        return it;
      },
    );
  }

  @override
  Future<Result<CallReceivedOrCreated>> getOrCreateCall({
    required StreamCallCid cid,
    List<String> participantIds = const [],
    bool ringing = false,
  }) async {
    _logger.d(
      () => '[getOrCreateCall] cid: $cid, ringing: $ringing, '
          'participantIds: $participantIds',
    );

    final currentUserId = _state.currentUser.value?.id;
    if (currentUserId == null) {
      _logger.e(() => '[getOrCreateCall] failed (no userId)');
      return Result.error('[createCall] failed; no user_id found');
    }

    final response = await _client.getOrCreateCall(
      input.GetOrCreateCallInput(
        callCid: cid,
        ringing: ringing,
        members: participantIds.map((id) {
          return input.MemberInput(
            userId: id,
            role: 'admin',
          );
        }),
      ),
    );

    return response.fold(
      success: (it) {
        _logger.v(() => '[getOrCreateCall] completed: ${it.data}');
        return it;
      },
      failure: (it) {
        _logger.e(() => '[getOrCreateCall] failed: ${it.error}');
        return it;
      },
    );
  }

  @override
  Future<Result<CallJoined>> joinCall({
    required StreamCallCid cid,
    void Function(CallReceivedOrCreated)? onReceivedOrCreated,
  }) async {
    _logger.d(() => '[joinCall] cid: $cid');
    final joinResult = await _client.joinCall(
      input.JoinCallInput(callCid: cid),
    );
    if (joinResult is! Success<CoordinatorJoined>) {
      _logger.e(() => '[joinCall] join failed: $joinResult');
      return joinResult as Failure;
    }
    onReceivedOrCreated?.call(
      CallReceivedOrCreated(
        wasCreated: joinResult.data.wasCreated,
        data: CallCreated(
          callCid: cid,
          ringing: false,
          metadata: joinResult.data.metadata,
        ),
      ),
    );
    _logger.v(() => '[joinCall] joinedMetadata: ${joinResult.data.metadata}');
    final edgeResult = await _client.findBestCallEdgeServer(
      callCid: cid,
      edges: joinResult.data.edges,
    );
    if (edgeResult is! Success<SfuServerSelected>) {
      _logger.e(() => '[joinCall] edge finding failed: $joinResult');
      return joinResult as Failure;
    }
    final call = CallJoined(
      callCid: cid,
      wasCreated: joinResult.data.wasCreated,
      metadata: edgeResult.data.metadata,
      credentials: edgeResult.data.credentials,
    );
    _logger.v(() => '[joinCall] completed: $call');
    return Result.success(call);
  }

  @override
  Future<Result<None>> acceptCall({
    required StreamCallCid cid,
  }) async {
    return _sendEvent(
      cid: cid,
      eventType: input.EventTypeInput.accepted,
    );
  }

  @override
  Future<Result<None>> rejectCall({
    required StreamCallCid cid,
  }) async {
    return _sendEvent(
      cid: cid,
      eventType: input.EventTypeInput.rejected,
    );
  }

  @override
  Future<Result<None>> cancelCall({
    required StreamCallCid cid,
  }) async {
    return _sendEvent(
      cid: cid,
      eventType: input.EventTypeInput.cancelled,
    );
  }

  Future<Result<None>> _sendEvent({
    required StreamCallCid cid,
    required input.EventTypeInput eventType,
  }) async {
    final result = await _client.sendUserEvent(
      input.EventInput(
        callCid: cid,
        eventType: eventType,
      ),
    );

    return result.fold(
      success: (_) => Result.success(None()),
      failure: (it) => it,
    );
  }

  @override
  Future<Result<None>> sendCustomEvent({
    required StreamCallCid cid,
    required String eventType,
    required Map<String, Object> extraData,
  }) async {
    final result = await _client.sendCustomEvent(
      input.CustomEventInput(
        callCid: cid,
        eventType: eventType,
        custom: extraData,
      ),
    );

    return result.fold(
      success: (_) => Result.success(None()),
      failure: (it) => it,
    );
  }

  @override
  Future<Result<List<CallUser>>> queryUsers({
    required StreamCallCid callCid,
    required Set<String> userIds,
  }) async {
    _logger.d(() => '[queryUsers] callCid: $callCid, userIds: $userIds');
    final usersResult = await _client.queryUsers(
      input.QueryUsersInput(
        callCid: callCid,
        filterConditions: {
          'id': {r'$in': userIds.toList()},
        },
      ),
    );
    return usersResult.fold(
      success: (it) {
        _logger.v(() => '[queryUsers] completed: ${it.data}');
        return Result.success(it.data);
      },
      failure: (it) {
        _logger.e(() => '[queryUsers] failed: $it');
        return it;
      },
    );
  }

  @override
  Future<Result<QueriedCalls>> queryCalls({
    required Map<String, Object> filterConditions,
    String? next,
    int? limit,
  }) {
    return _client.queryCalls(
      input.QueryCallsInput(
        filterConditions: filterConditions,
        next: next,
        limit: limit,
      ),
    );
  }

  @override
  Future<Result<None>> inviteUsers({
    required String callCid,
    required List<UserInfo> users,
  }) async {
    return _client.inviteUsers(
      input.UpsertCallMembersInput(
        callCid: StreamCallCid(cid: callCid),
        members: users.map((user) {
          return input.MemberInput(userId: user.id, role: user.role);
        }).toList(),
      ),
    );
  }

  @override
  Future<Result<None>> requestPermissions({
    required StreamCallCid callCid,
    required List<CallPermission> permissions,
  }) async {
    final result = await _client.requestPermissions(
      input.RequestPermissionsInput(
        callCid: callCid,
        permissions: permissions,
      ),
    );

    return result;
  }

  @override
  Future<Result<None>> updateUserPermissions({
    required StreamCallCid callCid,
    required String userId,
    List<CallPermission> grantPermissions = const [],
    List<CallPermission> revokePermissions = const [],
  }) async {
    final result = await _client.updateUserPermissions(
      input.UpdateUserPermissionsInput(
        callCid: callCid,
        userId: userId,
        grantPermissions: grantPermissions,
        revokePermissions: revokePermissions,
      ),
    );

    return result;
  }

  @override
  Future<Result<None>> startRecording({
    required StreamCallCid callCid,
  }) async {
    return _client.startRecording(callCid);
  }

  @override
  Future<Result<None>> stopRecording({
    required StreamCallCid callCid,
  }) {
    return _client.stopRecording(callCid);
  }

  @override
  Future<Result<None>> startBroadcasting({
    required StreamCallCid callCid,
  }) async {
    return _client.startBroadcasting(callCid);
  }

  @override
  Future<Result<None>> stopBroadcasting({
    required StreamCallCid callCid,
  }) async {
    return _client.stopBroadcasting(callCid);
  }

  @override
  Future<Result<None>> blockUser({
    required StreamCallCid callCid,
    required String userId,
  }) async {
    return _client.blockUser(BlockUserInput(callCid: callCid, userId: userId));
  }

  @override
  Future<Result<None>> unblockUser({
    required StreamCallCid callCid,
    required String userId,
  }) async {
    return _client.unblockUser(
      UnblockUserInput(
        callCid: callCid,
        userId: userId,
      ),
    );
  }

  @override
  Future<Result<CallMetadata>> goLive({
    required StreamCallCid callCid,
  }) async {
    return _client.goLive(callCid);
  }

  @override
  Future<Result<CallMetadata>> stopLive({
    required StreamCallCid callCid,
  }) async {
    return _client.stopLive(callCid);
  }

  @override
  Future<Result<None>> endCall({
    required StreamCallCid callCid,
  }) async {
    return _client.endCall(callCid);
  }

  @override
  Future<Result<None>> muteUsers({
    required StreamCallCid callCid,
    required List<String> userIds,
  }) async {
    return _client.muteUsers(
      input.MuteUsersInput(
        callCid: callCid,
        userIds: userIds,
      ),
    );
  }

  @override
  Future<Result<CallReaction>> sendReaction({
    required StreamCallCid callCid,
    required String reactionType,
    String? emojiCode,
    Map<String, Object> custom = const {},
  }) {
    return _client.sendReaction(
      input.ReactionInput(
        callCid: callCid,
        reactionType: reactionType,
        emojiCode: emojiCode,
        custom: custom,
      ),
    );
  }

  @override
  Future<Result<CallDevice>> createDevice({
    required String token,
    required String pushProviderId,
  }) async {
    return _client.createDevice(
      CreateDeviceInput(
        pushToken: token,
        pushProviderId: pushProviderId,
      ),
    );
  }

  @override
  Future<bool> handlePushNotification(Map<String, dynamic> payload) {
    return _pushNotificationManager?.handlePushNotification(payload) ??
        Future.value(false);
  }

  @override
  Future<CallCreated?> consumeIncomingCall() {
    return _pushNotificationManager?.consumeIncomingCall() ?? Future.value();
  }
}

class _StreamVideoState {
  final MutableStateEmitter<UserInfo?> currentUser = MutableStateEmitterImpl();

  Future<void> close() async {
    await currentUser.close();
  }
}

CoordinatorClient buildCoordinatorClient({
  required String rpcUrl,
  required String wsUrl,
  required String apiKey,
  required TokenManager tokenManager,
}) {
  return CoordinatorClientOpenApi(
    apiKey: apiKey,
    tokenManager: tokenManager,
    rpcUrl: rpcUrl,
    wsUrl: wsUrl,
  );
}
