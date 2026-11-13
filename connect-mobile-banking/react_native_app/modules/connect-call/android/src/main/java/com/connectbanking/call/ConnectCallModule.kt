package com.connectbanking.call

// Audio-only Amazon Connect web calling on Android, through the Amazon Chime SDK. It only joins (with the meeting and
// attendee from the app's backend, StartWebRTCContact's ConnectionData), mutes and leaves, and says what happened as
// one event, "ConnectCallEvent": connected, stopped (with the Chime status code), muted. Everything else (the
// participant hang-up, captions, the 25 s connect timeout) is the app's own code (CONTRACT.md section 5).
// The join token is used once and never logged.

import android.content.Intent
import androidx.core.content.ContextCompat
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
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.WritableMap
import com.facebook.react.modules.core.DeviceEventManagerModule
import org.json.JSONObject

class ConnectCallModule(private val context: ReactApplicationContext) :
    ReactContextBaseJavaModule(context), AudioVideoObserver, DeviceChangeObserver {
    private var session: DefaultMeetingSession? = null
    private var heardOn = "" // the devices the call was last routed for

    override fun getName() = "ConnectCall"

    private fun emit(build: WritableMap.() -> Unit) {
        val body = Arguments.createMap().apply(build)
        context.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java).emit("ConnectCallEvent", body)
    }

    // Android asks for the microphone from JavaScript (PermissionsAndroid); this is for iOS parity.
    @ReactMethod
    fun requestMicrophone(promise: Promise) {
        promise.resolve(ContextCompat.checkSelfPermission(context, android.Manifest.permission.RECORD_AUDIO) == android.content.pm.PackageManager.PERMISSION_GRANTED)
    }

    // Connect sends no ExternalUserId; the SDK needs one, so the attendee ID stands in.
    @ReactMethod
    fun join(meetingJson: String, attendeeJson: String, promise: Promise) {
        try {
            val meeting = JSONObject(meetingJson)
            val attendee = JSONObject(attendeeJson)
            val placement = meeting.getJSONObject("MediaPlacement")
            val attendeeId = attendee.getString("AttendeeId")
            val configuration = MeetingSessionConfiguration(
                CreateMeetingResponse(
                    Meeting(
                        meeting.optString("ExternalMeetingId").ifEmpty { null },
                        MediaPlacement(
                            placement.getString("AudioFallbackUrl"),
                            placement.getString("AudioHostUrl"),
                            placement.getString("SignalingUrl"),
                            placement.getString("TurnControlUrl"),
                            placement.optString("EventIngestionUrl").ifEmpty { null },
                        ),
                        meeting.getString("MediaRegion"),
                        meeting.getString("MeetingId"),
                    ),
                ),
                CreateAttendeeResponse(Attendee(attendeeId, attendee.optString("ExternalUserId").ifEmpty { attendeeId }, attendee.getString("JoinToken"))),
            )
            stopSession()
            val next = DefaultMeetingSession(configuration, ConsoleLogger(LogLevel.WARN), context.applicationContext)
            next.audioVideo.addAudioVideoObserver(this)
            next.audioVideo.addDeviceChangeObserver(this)
            startService()
            // Audio only: local video is never started. The SDK uses the voice-communication path (echo cancellation).
            next.audioVideo.start()
            session = next
            promise.resolve(null)
        } catch (error: Exception) {
            stopService()
            promise.reject("join_failed", "The call could not start.")
        }
    }

    @ReactMethod
    fun setMuted(muted: Boolean, promise: Promise) {
        session?.audioVideo?.let { if (muted) it.realtimeLocalMute() else it.realtimeLocalUnmute() }
        emit {
            putString("type", "muted")
            putBoolean("muted", muted)
        }
        promise.resolve(null)
    }

    @ReactMethod
    fun leave(promise: Promise) {
        stopSession()
        promise.resolve(null)
    }

    // Required by NativeEventEmitter.
    @ReactMethod
    fun addListener(eventName: String) {}

    @ReactMethod
    fun removeListeners(count: Double) {}

    override fun invalidate() {
        stopSession()
        super.invalidate()
    }

    private fun stopSession() {
        val current = session ?: return
        session = null
        heardOn = ""
        current.audioVideo.stop()
        current.audioVideo.removeAudioVideoObserver(this)
        current.audioVideo.removeDeviceChangeObserver(this)
        stopService()
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

    private fun startService() {
        ContextCompat.startForegroundService(context, Intent(context, CallService::class.java))
    }

    private fun stopService() {
        context.stopService(Intent(context, CallService::class.java))
    }

    // AudioVideoObserver

    override fun onAudioSessionStartedConnecting(reconnecting: Boolean) {}

    override fun onAudioSessionStarted(reconnecting: Boolean) {
        heardOn = ""
        session?.audioVideo?.let { routeAudio(it.listAudioDevices()) }
        if (!reconnecting) emit { putString("type", "connected") }
    }

    // DeviceChangeObserver

    override fun onAudioDeviceChanged(freshAudioDeviceList: List<MediaDevice>) {
        routeAudio(freshAudioDeviceList)
    }

    override fun onAudioSessionDropped() {}

    override fun onAudioSessionStopped(sessionStatus: MeetingSessionStatus) {
        stopService()
        emit {
            putString("type", "stopped")
            putInt("code", sessionStatus.statusCode?.value ?: -1)
        }
    }

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
