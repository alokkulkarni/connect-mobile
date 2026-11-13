// Audio-only Amazon Connect web calling on iOS, through the Amazon Chime SDK. It only joins (with the meeting and
// attendee from the app's backend, StartWebRTCContact's ConnectionData), mutes and leaves, and says what happened
// as one event, "ConnectCallEvent": connected, stopped (with the Chime status code), muted. Everything else (the
// participant hang-up, captions, the 25 s connect timeout) is the app's own code (CONTRACT.md section 5).
// The join token is used once and never logged.
import AVFoundation
import AmazonChimeSDK
import Foundation
import React

@objc(ConnectCall)
class ConnectCall: RCTEventEmitter, AudioVideoObserver, DeviceChangeObserver {
  private var session: DefaultMeetingSession?
  private var listening = false
  private var heardOn = ""     // the devices the call was last routed for

  override static func requiresMainQueueSetup() -> Bool { false }
  override func supportedEvents() -> [String]! { ["ConnectCallEvent"] }
  override func startObserving() { listening = true }
  override func stopObserving() { listening = false }

  private func emit(_ body: [String: Any]) {
    if listening { sendEvent(withName: "ConnectCallEvent", body: body) }
  }

  private func object(_ json: String) -> [String: Any]? {
    guard let data = json.data(using: .utf8) else { return nil }
    return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
  }

  @objc(requestMicrophone:rejecter:)
  func requestMicrophone(_ resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
    if #available(iOS 17.0, *) {
      AVAudioApplication.requestRecordPermission { granted in resolve(granted) }
    } else {
      AVAudioSession.sharedInstance().requestRecordPermission { granted in resolve(granted) }
    }
  }

  // Connect sends no ExternalUserId; the SDK needs one, so the attendee ID stands in.
  @objc(join:attendee:resolver:rejecter:)
  func join(_ meetingJson: String, attendee attendeeJson: String, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
    guard let meeting = object(meetingJson), let attendee = object(attendeeJson),
          let placement = meeting["MediaPlacement"] as? [String: Any],
          let meetingId = meeting["MeetingId"] as? String, let region = meeting["MediaRegion"] as? String,
          let audioHost = placement["AudioHostUrl"] as? String, let audioFallback = placement["AudioFallbackUrl"] as? String,
          let signaling = placement["SignalingUrl"] as? String, let turn = placement["TurnControlUrl"] as? String,
          let attendeeId = attendee["AttendeeId"] as? String, let joinToken = attendee["JoinToken"] as? String
    else {
      reject("join_failed", "The call could not start.", nil)
      return
    }
    let configuration = MeetingSessionConfiguration(
      createMeetingResponse: CreateMeetingResponse(meeting: Meeting(
        externalMeetingId: meeting["ExternalMeetingId"] as? String,
        mediaPlacement: MediaPlacement(audioFallbackUrl: audioFallback, audioHostUrl: audioHost, signalingUrl: signaling,
                                       turnControlUrl: turn, eventIngestionUrl: placement["EventIngestionUrl"] as? String),
        mediaRegion: region,
        meetingId: meetingId)),
      createAttendeeResponse: CreateAttendeeResponse(attendee: Attendee(
        attendeeId: attendeeId,
        externalUserId: (attendee["ExternalUserId"] as? String) ?? attendeeId,
        joinToken: joinToken)))
    DispatchQueue.main.async {
      self.stopSession()
      let session = DefaultMeetingSession(configuration: configuration, logger: ConsoleLogger(name: "call", level: .ERROR))
      session.audioVideo.addAudioVideoObserver(observer: self)
      session.audioVideo.addDeviceChangeObserver(observer: self)
      do {
        try ConnectCall.allowHeadsets()
        // Audio only: local video is never started. The voice-chat mode gives echo cancellation.
        try session.audioVideo.start()
        self.session = session
        resolve(nil)
      } catch {
        session.audioVideo.removeAudioVideoObserver(observer: self)
        session.audioVideo.removeDeviceChangeObserver(observer: self)
        reject("join_failed", "The call could not start.", nil)
      }
    }
  }

  @objc(setMuted:resolver:rejecter:)
  func setMuted(_ muted: Bool, resolver resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
    guard let session = session else { resolve(nil); return }
    _ = muted ? session.audioVideo.realtimeLocalMute() : session.audioVideo.realtimeLocalUnmute()
    emit(["type": "muted", "muted": muted])
    resolve(nil)
  }

  @objc(leave:rejecter:)
  func leave(_ resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
    DispatchQueue.main.async {
      self.stopSession()
      resolve(nil)
    }
  }

  private func stopSession() {
    guard let session = session else { return }
    self.session = nil
    heardOn = ""
    session.audioVideo.stop()
    session.audioVideo.removeAudioVideoObserver(observer: self)
    session.audioVideo.removeDeviceChangeObserver(observer: self)
  }

  // A voice call that may use Bluetooth (HFP carries the microphone too) and wired headsets, and the loudspeaker
  // rather than the earpiece when there's neither.
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

  // MARK: AudioVideoObserver

  func audioSessionDidStartConnecting(reconnecting: Bool) {}
  func audioSessionDidStart(reconnecting: Bool) {
    DispatchQueue.main.async {
      try? ConnectCall.allowHeadsets()      // in case starting the call reset the audio session's options
      self.heardOn = ""
      if let audio = self.session?.audioVideo { self.routeAudio(audio.listAudioDevices()) }
    }
    if !reconnecting { emit(["type": "connected"]) }
  }

  // MARK: DeviceChangeObserver

  func audioDeviceDidChange(freshAudioDeviceList: [MediaDevice]) {
    DispatchQueue.main.async { self.routeAudio(freshAudioDeviceList) }
  }
  func audioSessionDidDrop() {}
  func audioSessionDidStopWithStatus(sessionStatus: MeetingSessionStatus) {
    emit(["type": "stopped", "code": Int(sessionStatus.statusCode.rawValue)])
  }
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
