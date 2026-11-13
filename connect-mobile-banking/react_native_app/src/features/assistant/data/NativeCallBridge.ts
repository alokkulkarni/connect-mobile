// The native call module, ConnectCall (ios/ConnectBanking/ConnectCall.swift, android/.../ConnectCallModule.kt),
// on the Amazon Chime SDK. It joins with Connect's meeting and attendee, mutes, leaves, and says what happened.
import { NativeEventEmitter, NativeModules, PermissionsAndroid, Platform } from 'react-native';
import type { CallBridge, CallEvent, Microphone } from '../domain/ports';

type Native = {
  join(meeting: string, attendee: string): Promise<void>;
  setMuted(muted: boolean): Promise<void>;
  leave(): Promise<void>;
  requestMicrophone(): Promise<boolean>;
  addListener(name: string): void;
  removeListeners(count: number): void;
};

const EVENT = 'ConnectCallEvent';
const native = (): Native | null => (NativeModules.ConnectCall as Native | undefined) || null;
const UNAVAILABLE = "Calls aren't available on this device. Use Chat.";

export class NativeCallBridge implements CallBridge {
  private emitter: NativeEventEmitter | null = null;

  async join(meeting: Record<string, unknown>, attendee: Record<string, unknown>): Promise<void> {
    const module = native();
    if (!module) throw new Error(UNAVAILABLE);
    await module.join(JSON.stringify(meeting), JSON.stringify(attendee));
  }

  async setMuted(muted: boolean): Promise<void> {
    await native()?.setMuted(muted);
  }

  async leave(): Promise<void> {
    await native()?.leave();
  }

  onEvent(listener: (event: CallEvent) => void): () => void {
    const module = native();
    if (!module) return () => {};
    this.emitter = this.emitter || new NativeEventEmitter(NativeModules.ConnectCall);
    const subscription = this.emitter.addListener(EVENT, (raw: { type?: string; code?: number; muted?: boolean; message?: string }) => {
      if (raw.type === 'connected') listener({ type: 'connected' });
      else if (raw.type === 'stopped') listener({ type: 'stopped', code: Number(raw.code ?? -1) });
      else if (raw.type === 'muted') listener({ type: 'muted', muted: Boolean(raw.muted) });
      else if (raw.type === 'error') listener({ type: 'error', message: String(raw.message || '') });
    });
    return () => subscription.remove();
  }
}

export class PlatformMicrophone implements Microphone {
  async request(): Promise<boolean> {
    if (Platform.OS === 'android') {
      const result = await PermissionsAndroid.request(PermissionsAndroid.PERMISSIONS.RECORD_AUDIO);
      return result === PermissionsAndroid.RESULTS.GRANTED;
    }
    const module = native();
    return module ? module.requestMicrophone() : false;
  }
}
