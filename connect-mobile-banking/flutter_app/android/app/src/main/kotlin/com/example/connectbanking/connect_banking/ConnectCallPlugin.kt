package com.example.connectbanking.connect_banking

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.amazonaws.services.chime.sdk.meetings.audiovideo.AudioVideoObserver
import com.amazonaws.services.chime.sdk.meetings.audiovideo.video.RemoteVideoSource
import com.amazonaws.services.chime.sdk.meetings.device.DeviceChangeObserver
import com.amazonaws.services.chime.sdk.meetings.device.MediaDevice
import com.amazonaws.services.chime.sdk.meetings.device.MediaDeviceType
import com.amazonaws.services.chime.sdk.meetings.session.Attendee
import com.amazonaws.services.chime.sdk.meetings.session.CreateAttendeeResponse
import com.amazonaws.services.chime.sdk.meetings.session.CreateMeetingResponse
import com.amazonaws.services.chime.sdk.meetings.session.DefaultMeetingSession
import com.amazonaws.services.chime.sdk.meetings.session.MediaPlacement
import com.amazonaws.services.chime.sdk.meetings.session.Meeting
import com.amazonaws.services.chime.sdk.meetings.session.MeetingSessionConfiguration
import com.amazonaws.services.chime.sdk.meetings.session.MeetingSessionStatus
import com.amazonaws.services.chime.sdk.meetings.utils.logger.ConsoleLogger
import com.amazonaws.services.chime.sdk.meetings.utils.logger.LogLevel
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

// The call's audio, on the Amazon Chime SDK for Android, for the Dart side (lib/features/assistant/data/native_call.dart).
// Dart owns the call's sequence; this only joins, mutes and leaves. Audio only: local video is never started.
//   methods  join({meeting, attendee}), setMuted({muted}), leave()
//   events   {type: connected}, {type: stopped, code}, {type: error, message}
// meeting and attendee are StartWebRTCContact's ConnectionData. Connect sends no ExternalUserId, so the AttendeeId
// stands in for it. The join token is used here and nowhere else: never logged.
class ConnectCallPlugin(private val context: Context, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler, AudioVideoObserver, DeviceChangeObserver {

    private val methods = MethodChannel(messenger, "connect_call")
    private val events = EventChannel(messenger, "connect_call/events")
    private val main = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null
    private var session: DefaultMeetingSession? = null
    private var heardOn = "" // the devices the call was last routed for

    init {
        methods.setMethodCallHandler(this)
        events.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "join" -> try {
                @Suppress("UNCHECKED_CAST")
                join(call.argument<Map<String, Any?>>("meeting") ?: emptyMap(), call.argument<Map<String, Any?>>("attendee") ?: emptyMap())
                result.success(null)
            } catch (error: Exception) {
                leave()
                result.error("join_failed", "The call could not start.", null)
            }
            "setMuted" -> {
                val audio = session?.audioVideo
                if (call.argument<Boolean>("muted") == true) audio?.realtimeLocalMute() else audio?.realtimeLocalUnmute()
                result.success(null)
            }
            "leave" -> {
                leave()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun text(map: Map<String, Any?>, key: String): String =
        map[key] as? String ?: throw IllegalArgumentException("missing $key")

    private fun join(meeting: Map<String, Any?>, attendee: Map<String, Any?>) {
        leave()
        @Suppress("UNCHECKED_CAST")
        val placement = meeting["MediaPlacement"] as? Map<String, Any?> ?: throw IllegalArgumentException("missing MediaPlacement")
        val configuration = MeetingSessionConfiguration(
            CreateMeetingResponse(
                Meeting(
                    null,
                    MediaPlacement(
                        text(placement, "AudioFallbackUrl"),
                        text(placement, "AudioHostUrl"),
                        text(placement, "SignalingUrl"),
                        text(placement, "TurnControlUrl"),
                        placement["EventIngestionUrl"] as? String,
                    ),
                    text(meeting, "MediaRegion"),
                    text(meeting, "MeetingId"),
                ),
            ),
            CreateAttendeeResponse(Attendee(text(attendee, "AttendeeId"), text(attendee, "AttendeeId"), text(attendee, "JoinToken"))),
        )
        val created = DefaultMeetingSession(configuration, ConsoleLogger(LogLevel.WARN), context)
        session = created
        created.audioVideo.addAudioVideoObserver(this)
        created.audioVideo.addDeviceChangeObserver(this)
        CallService.start(context) // keeps the microphone working while the app is in the background
        created.audioVideo.start()
    }

    private fun leave() {
        session?.let {
            it.audioVideo.removeAudioVideoObserver(this)
            it.audioVideo.removeDeviceChangeObserver(this)
            it.audioVideo.stop()
        }
        session = null
        heardOn = ""
        CallService.stop(context)
    }

    // Where the call is heard: a Bluetooth headset if one is connected, then a wired or USB one, otherwise the
    // loudspeaker. The Chime SDK starts on the phone's earpiece, which sounds like a silent call when the phone isn't
    // at your ear. Again whenever a headset comes or goes during the call; never twice for the same devices.
    private fun routeAudio(devices: List<MediaDevice>) {
        val audio = session?.audioVideo ?: return
        val signature = devices.map { "${it.type}:${it.label}" }.sorted().joinToString("|")
        if (signature == heardOn) return
        heardOn = signature
        val preferred = listOf(
            MediaDeviceType.AUDIO_BLUETOOTH,
            MediaDeviceType.AUDIO_WIRED_HEADSET,
            MediaDeviceType.AUDIO_USB_HEADSET,
            MediaDeviceType.AUDIO_BUILTIN_SPEAKER,
        )
        preferred.firstNotNullOfOrNull { kind -> devices.firstOrNull { it.type == kind } }?.let { audio.chooseAudioDevice(it) }
    }

    private fun emit(event: Map<String, Any?>) {
        main.post { sink?.success(event) }
    }

    fun dispose() {
        leave()
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
    }

    // EventChannel.StreamHandler
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    // AudioVideoObserver: only the audio session's start and stop matter for an audio-only call.
    override fun onAudioSessionStarted(reconnecting: Boolean) {
        heardOn = ""
        session?.audioVideo?.let { routeAudio(it.listAudioDevices()) }
        if (!reconnecting) emit(mapOf("type" to "connected"))
    }

    // DeviceChangeObserver: a headset came or went during the call.
    override fun onAudioDeviceChanged(freshAudioDeviceList: List<MediaDevice>) {
        routeAudio(freshAudioDeviceList)
    }

    override fun onAudioSessionStopped(sessionStatus: MeetingSessionStatus) {
        session?.audioVideo?.removeAudioVideoObserver(this)
        session?.audioVideo?.removeDeviceChangeObserver(this)
        session = null
        heardOn = ""
        CallService.stop(context)
        emit(mapOf("type" to "stopped", "code" to (sessionStatus.statusCode?.value ?: -1)))
    }

    override fun onAudioSessionStartedConnecting(reconnecting: Boolean) {}
    override fun onAudioSessionDropped() {}
    override fun onAudioSessionCancelledReconnect() {}
    override fun onConnectionRecovered() {}
    override fun onConnectionBecamePoor() {}
    override fun onVideoSessionStartedConnecting() {}
    override fun onVideoSessionStarted(sessionStatus: MeetingSessionStatus) {}
    override fun onVideoSessionStopped(sessionStatus: MeetingSessionStatus) {}
    override fun onRemoteVideoSourceUnavailable(sources: List<RemoteVideoSource>) {}
    override fun onRemoteVideoSourceAvailable(sources: List<RemoteVideoSource>) {}
    override fun onCameraSendAvailabilityUpdated(available: Boolean) {}
}
