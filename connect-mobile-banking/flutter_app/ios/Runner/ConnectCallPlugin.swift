import AmazonChimeSDK
import AVFoundation
import Flutter
import UIKit

// The call's audio, on the Amazon Chime SDK for iOS, for the Dart side (lib/features/assistant/data/native_call.dart).
// Dart owns the call's sequence; this only joins, mutes and leaves. Audio only: local video is never started.
//   methods  join({meeting, attendee}), setMuted({muted}), leave()
//   events   {type: connected}, {type: stopped, code}, {type: error, message}
// meeting and attendee are StartWebRTCContact's ConnectionData. Connect sends no ExternalUserId, so the AttendeeId
// stands in for it. The join token is used here and nowhere else: never logged.
final class ConnectCallPlugin: NSObject, FlutterStreamHandler, AudioVideoObserver, DeviceChangeObserver {
  private var sink: FlutterEventSink?
  private var session: DefaultMeetingSession?
  private var heardOn = ""     // the devices the call was last routed for

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = ConnectCallPlugin()
    let methods = FlutterMethodChannel(name: "connect_call", binaryMessenger: registrar.messenger())
    let events = FlutterEventChannel(name: "connect_call/events", binaryMessenger: registrar.messenger())
    methods.setMethodCallHandler { call, result in instance.handle(call, result: result) }
    events.setStreamHandler(instance)
  }

  private enum JoinError: Error { case missing(String) }

  private func text(_ map: [String: Any]?, _ key: String) throws -> String {
    guard let value = map?[key] as? String else { throw JoinError.missing(key) }
    return value
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    switch call.method {
    case "join":
      do {
        try join(meeting: args?["meeting"] as? [String: Any], attendee: args?["attendee"] as? [String: Any])
        result(nil)
      } catch {
        leave()
        result(FlutterError(code: "join_failed", message: "The call could not start.", details: nil))
      }
    case "setMuted":
      if (args?["muted"] as? Bool) == true {
        _ = session?.audioVideo.realtimeLocalMute()
      } else {
        _ = session?.audioVideo.realtimeLocalUnmute()
      }
      result(nil)
    case "leave":
      leave()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func join(meeting: [String: Any]?, attendee: [String: Any]?) throws {
    leave()
    let placement = meeting?["MediaPlacement"] as? [String: Any]
    let configuration = MeetingSessionConfiguration(
      createMeetingResponse: CreateMeetingResponse(meeting: Meeting(
        externalMeetingId: nil,
        mediaPlacement: MediaPlacement(
          audioFallbackUrl: try text(placement, "AudioFallbackUrl"),
          audioHostUrl: try text(placement, "AudioHostUrl"),
          signalingUrl: try text(placement, "SignalingUrl"),
          turnControlUrl: try text(placement, "TurnControlUrl"),
          eventIngestionUrl: placement?["EventIngestionUrl"] as? String),
        mediaRegion: try text(meeting, "MediaRegion"),
        meetingId: try text(meeting, "MeetingId"))),
      createAttendeeResponse: CreateAttendeeResponse(attendee: Attendee(
        attendeeId: try text(attendee, "AttendeeId"),
        externalUserId: try text(attendee, "AttendeeId"),
        joinToken: try text(attendee, "JoinToken"))))
    try ConnectCallPlugin.allowHeadsets()
    let created = DefaultMeetingSession(configuration: configuration, logger: ConsoleLogger(name: "call", level: .ERROR))
    session = created
    created.audioVideo.addAudioVideoObserver(observer: self)
    created.audioVideo.addDeviceChangeObserver(observer: self)
    try created.audioVideo.start()
  }

  private func leave() {
    if let current = session {
      current.audioVideo.removeAudioVideoObserver(observer: self)
      current.audioVideo.removeDeviceChangeObserver(observer: self)
      current.audioVideo.stop()
    }
    session = nil
    heardOn = ""
  }

  // The voice-processing path (so Connect doesn't hear the assistant's own voice as the customer interrupting), able
  // to use Bluetooth (HFP carries the microphone too) and wired headsets, and the loudspeaker rather than the earpiece
  // when there's neither.
  private static func allowHeadsets() throws {
    try AVAudioSession.sharedInstance().setCategory(
      .playAndRecord, mode: .voiceChat, options: [.allowBluetoothHFP, .allowBluetoothA2DP, .defaultToSpeaker])
  }

  // Where the call is heard: a Bluetooth headset if one is connected, then a wired one, otherwise the loudspeaker.
  // The Chime SDK starts on the phone's earpiece, which sounds like a silent call when the phone isn't at your ear.
  // Again whenever a headset comes or goes during the call; never twice for the same devices.
  private func routeAudio(_ devices: [MediaDevice]) {
    guard let audio = session?.audioVideo else { return }
    let signature = devices.map { "\($0.type.rawValue):\($0.label)" }.sorted().joined(separator: "|")
    if signature == heardOn { return }
    heardOn = signature
    for kind in [MediaDeviceType.audioBluetooth, .audioWiredHeadset, .audioBuiltInSpeaker] {
      if let device = devices.first(where: { $0.type == kind }) {
        audio.chooseAudioDevice(mediaDevice: device)
        return
      }
    }
    try? AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
  }

  private func emit(_ event: [String: Any]) {
    DispatchQueue.main.async { self.sink?(event) }
  }

  // FlutterStreamHandler
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  // AudioVideoObserver: only the audio session's start and stop matter for an audio-only call.
  func audioSessionDidStart(reconnecting: Bool) {
    DispatchQueue.main.async {
      try? ConnectCallPlugin.allowHeadsets()      // in case starting the call reset the audio session's options
      self.heardOn = ""
      if let audio = self.session?.audioVideo { self.routeAudio(audio.listAudioDevices()) }
    }
    if !reconnecting { emit(["type": "connected"]) }
  }

  // DeviceChangeObserver: a headset came or went during the call.
  func audioDeviceDidChange(freshAudioDeviceList: [MediaDevice]) {
    DispatchQueue.main.async { self.routeAudio(freshAudioDeviceList) }
  }

  func audioSessionDidStopWithStatus(sessionStatus: MeetingSessionStatus) {
    session?.audioVideo.removeAudioVideoObserver(observer: self)
    session?.audioVideo.removeDeviceChangeObserver(observer: self)
    session = nil
    heardOn = ""
    emit(["type": "stopped", "code": Int(sessionStatus.statusCode.rawValue)])
  }

  func audioSessionDidStartConnecting(reconnecting: Bool) {}
  func audioSessionDidDrop() {}
  func audioSessionDidCancelReconnect() {}
  func connectionDidRecover() {}
  func connectionDidBecomePoor() {}
  func videoSessionDidStartConnecting() {}
  func videoSessionDidStartWithStatus(sessionStatus: MeetingSessionStatus) {}
  func videoSessionDidStopWithStatus(sessionStatus: MeetingSessionStatus) {}
  func remoteVideoSourcesDidBecomeAvailable(sources: [RemoteVideoSource]) {}
  func remoteVideoSourcesDidBecomeUnavailable(sources: [RemoteVideoSource]) {}
  func cameraSendAvailabilityDidChange(available: Bool) {}
}
