// The session in the platform's secure store (iOS Keychain, Android Keystore), never in plain preferences.
// The web app keeps its link in localStorage; this is the mobile equivalent (CONTRACT.md section 1).
import { Platform, Settings } from 'react-native';
import * as Keychain from 'react-native-keychain';
import { Session, SessionRepository } from '../domain/session';

const SERVICE = 'internet-banking-session';
// iOS keeps Keychain items after the app is deleted; its settings (UserDefaults) go with the app. A missing mark means
// this is the first launch since installing, so a session in the Keychain belongs to an earlier install: forget it.
// (Android removes the app's keystore data on uninstall.)
const INSTALLED = 'internetBankingInstalled';

export class KeychainSessionRepository implements SessionRepository {
  async load(): Promise<Session | null> {
    try {
      if (Platform.OS === 'ios' && !Settings.get(INSTALLED)) {
        await Keychain.resetGenericPassword({ service: SERVICE });
        Settings.set({ [INSTALLED]: 1 });
        return null;
      }
      const found = await Keychain.getGenericPassword({ service: SERVICE });
      if (!found) return null;
      const session = JSON.parse(found.password) as Session;
      if (session.mode === 'link' && session.origin && session.secret) return session;
      return null;
    } catch {
      return null;
    }
  }

  async save(session: Session): Promise<void> {
    await Keychain.setGenericPassword('session', JSON.stringify(session), {
      service: SERVICE,
      accessible: Keychain.ACCESSIBLE.WHEN_UNLOCKED_THIS_DEVICE_ONLY,
    });
  }

  async clear(): Promise<void> {
    await Keychain.resetGenericPassword({ service: SERVICE });
  }
}
