import { appRecovery, common, errorManager } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { RECOVERY_MESSAGE_KEY } from '../models/RecoveryCheckpoint';
import { incidentTimelineStore } from './IncidentTimelineStore';

export const GUARD_OBSERVER_ACTIVE_KEY: string = 'guardObserverActive';
export const GUARD_CAPTURE_ENABLED_KEY: string = 'guardCaptureEnabled';
export const GUARD_FEEDBACK_KEY: string = 'guardFeedback';
export const GUARD_LAST_RESTART_AT_KEY: string = 'guardLastRestartAt';
export const GUARD_LOOP_DEMO_STATUS_KEY: string = 'guardLoopDemoStatus';

const DOMAIN: number = 0x0000;
const TAG: string = 'RecoveryGuardService';
const RESTART_COOLDOWN_MS: number = 60 * 1000;
const GUARD_PREFERENCES_NAME: string = 'crash_recovery_guard_state';
const LOOP_OBSERVER_TIMEOUT_MS: number = 200;
const LOOP_SIMULATION_STALL_MS: number = 800;

export class RecoveryGuardService {
  private storage?: LocalStorage;
  private dataPreferences?: preferences.Preferences;
  private observerId: number = -1;
  private unregisteringObserver: boolean = false;
  private registerPending: boolean = false;
  private loopObserverRegistered: boolean = false;
  private observer: errorManager.ErrorObserver = {
    onUnhandledException: (errorMsg: string): void => {
      incidentTimelineStore.add('Observer caught unhandled exception; state save requested.');
      hilog.error(DOMAIN, TAG, 'Unhandled exception observed: %{public}s', errorMsg.substring(0, 120));
      this.saveCheckpoint('Observer auto-save');
      this.requestRestart('Observer restart');
    },
    onException: (errorObj: Error): void => {
      incidentTimelineStore.add(`Observer noticed exception: ${errorObj.name}`);
    }
  };
  private loopObserver: errorManager.LoopObserver = {
    onLoopTimeOut: (timeout: number): void => {
      const message: string = `LoopObserver reported the intentional main-thread stall (${timeout}ms); no crash recovery or restart was requested.`;
      this.setLoopDemoStatus(message);
      this.setFeedback('LoopObserver callback reported the stall');
      incidentTimelineStore.add(message);
      hilog.warn(DOMAIN, TAG, 'Loop timeout observed: %{public}d ms', timeout);
    }
  };

  bind(storage: LocalStorage, context?: common.UIAbilityContext): void {
    this.storage = storage;
    incidentTimelineStore.bind(storage);
    this.bindPreferences(context);
    storage.setOrCreate(GUARD_CAPTURE_ENABLED_KEY, this.readPersistedCaptureEnabled());
    storage.setOrCreate(GUARD_OBSERVER_ACTIVE_KEY, this.isRegistered());
    storage.setOrCreate(GUARD_FEEDBACK_KEY, 'Guard ready');
    const persistedLastRestartAt: number = this.readPersistedLastRestartAt();
    storage.setOrCreate(GUARD_LAST_RESTART_AT_KEY, persistedLastRestartAt);
    storage.setOrCreate(GUARD_LOOP_DEMO_STATUS_KEY, '');
  }

  registerObserver(): void {
    if (this.unregisteringObserver) {
      this.registerPending = true;
      this.setFeedback('Observer turning on');
      return;
    }
    if (this.observerId >= 0) {
      this.registerPending = false;
      this.setActive(true);
      return;
    }
    try {
      this.observerId = errorManager.on('error', this.observer);
      this.registerPending = false;
      this.setActive(true);
      this.setFeedback('Observer on');
      incidentTimelineStore.add('Recovery observer enabled.');
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      this.setActive(false);
      this.setFeedback(`Observer register failed: ${error.code}`);
      incidentTimelineStore.add(`Observer registration failed: ${error.message}`);
    }
  }

  unregisterObserver(): void {
    this.unregisterCrashObserver('Window cleanup');
    this.unregisterLoopObserver();
  }

  enableCrashGuard(): void {
    this.setCaptureEnabled(true);
    this.registerObserver();
  }

  disableCrashGuard(): void {
    this.setCaptureEnabled(false);
    this.unregisterCrashObserver('Recovery observer off');
  }

  shouldAutoRegister(): boolean {
    return this.storage?.get<boolean>(GUARD_CAPTURE_ENABLED_KEY) ?? true;
  }

  triggerJsErrorTest(): void {
    const captureEnabled: boolean = this.storage?.get<boolean>(GUARD_CAPTURE_ENABLED_KEY) ?? true;
    if (!captureEnabled && this.unregisteringObserver) {
      this.setFeedback('Observer is turning off');
      return;
    }
    const captureActive: boolean = captureEnabled && this.isRegistered();
    if (captureActive && !this.canRestartNow()) {
      this.recordRestartCooldownBlock('JS error trigger');
      return;
    }
    this.setFeedback(captureActive ? 'Triggering observed JS error' : 'Triggering platform-only JS error');
    incidentTimelineStore.add(captureActive ? 'JS error test started with recovery observer on.' :
      'JS error test started with observer off; platform recovery remains enabled.');
    setTimeout(() => {
      throw new Error('Recovery Guard controlled JS error');
    }, 20);
  }

  private unregisterCrashObserver(label: string): void {
    this.registerPending = false;
    if (this.unregisteringObserver) {
      this.setFeedback('Turning observer off');
      return;
    }
    if (this.observerId < 0) {
      this.setActive(false);
      return;
    }
    const id: number = this.observerId;
    this.unregisteringObserver = true;
    this.setFeedback('Turning observer off');
    try {
      errorManager.off('error', id).then(() => {
        if (this.observerId === id) {
          this.observerId = -1;
        }
        this.unregisteringObserver = false;
        incidentTimelineStore.add(`${label}: ErrorObserver unregistered.`);
        if (this.registerPending) {
          this.registerPending = false;
          this.registerObserver();
        } else {
          this.setActive(false);
          this.setFeedback('Observer off');
        }
      }).catch((err: BusinessError) => {
        this.unregisteringObserver = false;
        this.registerPending = false;
        this.setActive(this.observerId >= 0);
        this.setFeedback(`Observer unregister failed: ${err.code}`);
        incidentTimelineStore.add(`Observer unregister failed: ${err.message}`);
      });
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      this.unregisteringObserver = false;
      this.registerPending = false;
      this.setActive(this.observerId >= 0);
      this.setFeedback(`Observer unregister failed: ${error.code}`);
      incidentTimelineStore.add(`Observer unregister failed: ${error.message}`);
    }
  }

  saveCheckpoint(label: string = 'Manual save'): boolean {
    let saved: boolean = false;
    try {
      saved = appRecovery.saveAppState();
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      this.setFeedback(`Save failed: ${error.code}`);
      incidentTimelineStore.add(`${label} failed: ${error.message}`);
      return false;
    }
    this.setFeedback(saved ? `${label} complete` : `${label} returned false`);
    incidentTimelineStore.add(saved ? `${label}: appRecovery.saveAppState() complete.` : `${label}: save returned false.`);
    return saved;
  }

  simulateRecoverableRestart(): void {
    if (!this.canRestartNow()) {
      this.recordRestartCooldownBlock('Restart test');
      return;
    }
    this.saveCheckpoint('Simulation save');
    this.requestRestart('Documented restart simulation');
  }

  simulateLoopTimeout(): void {
    const startMessage: string = `Starting demo-only ${LOOP_SIMULATION_STALL_MS}ms busy wait on the main thread; this intentionally exceeds the ${LOOP_OBSERVER_TIMEOUT_MS}ms LoopObserver threshold.`;
    this.setFeedback('Intentionally blocking main thread for loop demo');
    this.setLoopDemoStatus('Blocking main thread now for a bounded loop demo; this is not crash recovery and will not restart the app.');
    incidentTimelineStore.add(startMessage);
    const endAt: number = Date.now() + LOOP_SIMULATION_STALL_MS;
    while (Date.now() < endAt) {
    }
    this.setFeedback('Loop demo returned without restart');
    this.setLoopDemoStatus('UI returned after the intentional stall. If the emulator delivers it, LoopObserver will also report the timeout separately.');
    incidentTimelineStore.add('UI returned after bounded loop timeout demo; no appRecovery restart was requested.');
  }

  resetDemo(): void {
    this.storage?.setOrCreate(RECOVERY_MESSAGE_KEY, 'Checkpoint 1: baseline');
    this.setLastRestartAt(0);
    this.setFeedback('Demo reset');
    this.setLoopDemoStatus('');
    incidentTimelineStore.resetWithEvent('Demo reset; checkpoint returned to baseline.');
  }

  canRestartNow(): boolean {
    return this.remainingCooldownMs() <= 0;
  }

  remainingCooldownMs(): number {
    const lastRestartAt: number = this.storage?.get<number>(GUARD_LAST_RESTART_AT_KEY) ?? 0;
    const elapsed: number = Date.now() - lastRestartAt;
    return Math.max(0, RESTART_COOLDOWN_MS - elapsed);
  }

  private requestRestart(label: string): void {
    if (!this.canRestartNow()) {
      this.recordRestartCooldownBlock(label);
      return;
    }
    this.setLastRestartAt(Date.now());
    this.setFeedback(`${label}: restart requested`);
    incidentTimelineStore.add(`${label}: appRecovery.restartApp() requested.`);
    appRecovery.restartApp();
  }

  private bindPreferences(context?: common.UIAbilityContext): void {
    if (context === undefined || this.dataPreferences !== undefined) {
      return;
    }
    try {
      const options: preferences.Options = { name: GUARD_PREFERENCES_NAME };
      this.dataPreferences = preferences.getPreferencesSync(context, options);
    } catch (err) {
      this.dataPreferences = undefined;
    }
  }

  private readPersistedLastRestartAt(): number {
    if (this.dataPreferences === undefined) {
      return this.storage?.get<number>(GUARD_LAST_RESTART_AT_KEY) ?? 0;
    }
    try {
      const persisted: preferences.ValueType = this.dataPreferences.getSync(GUARD_LAST_RESTART_AT_KEY, 0);
      if (typeof persisted === 'number') {
        return persisted;
      }
    } catch (err) {
      return 0;
    }
    return 0;
  }

  private readPersistedCaptureEnabled(): boolean {
    if (this.dataPreferences === undefined) {
      return this.storage?.get<boolean>(GUARD_CAPTURE_ENABLED_KEY) ?? true;
    }
    try {
      const persisted: preferences.ValueType = this.dataPreferences.getSync(GUARD_CAPTURE_ENABLED_KEY, true);
      if (typeof persisted === 'boolean') {
        return persisted;
      }
    } catch (err) {
      return true;
    }
    return true;
  }

  private setLastRestartAt(value: number): void {
    this.setStorageNumber(GUARD_LAST_RESTART_AT_KEY, value);
    if (this.dataPreferences !== undefined) {
      try {
        this.dataPreferences.putSync(GUARD_LAST_RESTART_AT_KEY, value);
        this.dataPreferences.flushSync();
      } catch (err) {
        incidentTimelineStore.add('Restart cooldown persistence failed.');
      }
    }
  }

  private isRegistered(): boolean {
    return this.observerId >= 0;
  }

  registerLoopObserver(): void {
    if (this.loopObserverRegistered) {
      return;
    }
    try {
      errorManager.on('loopObserver', LOOP_OBSERVER_TIMEOUT_MS, this.loopObserver);
      this.loopObserverRegistered = true;
      incidentTimelineStore.add(`LoopObserver registered at ${LOOP_OBSERVER_TIMEOUT_MS}ms threshold.`);
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      this.loopObserverRegistered = false;
      incidentTimelineStore.add(`LoopObserver registration failed: ${error.message}`);
    }
  }

  private unregisterLoopObserver(): void {
    if (!this.loopObserverRegistered) {
      return;
    }
    this.loopObserverRegistered = false;
    try {
      errorManager.off('loopObserver', this.loopObserver);
      incidentTimelineStore.add('LoopObserver unregistered on window destroy.');
    } catch (err) {
      const error: BusinessError = err as BusinessError;
      incidentTimelineStore.add(`LoopObserver unregister failed: ${error.message}`);
    }
  }

  private setActive(active: boolean): void {
    this.setStorageBoolean(GUARD_OBSERVER_ACTIVE_KEY, active);
  }

  private setCaptureEnabled(enabled: boolean): void {
    this.setStorageBoolean(GUARD_CAPTURE_ENABLED_KEY, enabled);
    if (this.dataPreferences !== undefined) {
      try {
        this.dataPreferences.putSync(GUARD_CAPTURE_ENABLED_KEY, enabled);
        this.dataPreferences.flushSync();
      } catch (err) {
        incidentTimelineStore.add('Observer preference persistence failed.');
      }
    }
  }

  private setFeedback(message: string): void {
    this.setStorageString(GUARD_FEEDBACK_KEY, message);
  }

  private setLoopDemoStatus(message: string): void {
    this.setStorageString(GUARD_LOOP_DEMO_STATUS_KEY, message);
  }

  private setStorageBoolean(key: string, value: boolean): void {
    if (this.storage === undefined) {
      return;
    }
    if (this.storage.get<boolean>(key) === undefined) {
      this.storage.setOrCreate(key, value);
      return;
    }
    this.storage.set(key, value);
  }

  private setStorageNumber(key: string, value: number): void {
    if (this.storage === undefined) {
      return;
    }
    if (this.storage.get<number>(key) === undefined) {
      this.storage.setOrCreate(key, value);
      return;
    }
    this.storage.set(key, value);
  }

  private setStorageString(key: string, value: string): void {
    if (this.storage === undefined) {
      return;
    }
    if (this.storage.get<string>(key) === undefined) {
      this.storage.setOrCreate(key, value);
      return;
    }
    this.storage.set(key, value);
  }

  private recordRestartCooldownBlock(label: string): void {
    const seconds: number = Math.ceil(this.remainingCooldownMs() / 1000);
    this.setFeedback(`Restart cooling down. Try again in ${seconds}s`);
    incidentTimelineStore.add(`${label}: appRecovery.restartApp() one-minute restart limit (${seconds}s left).`);
  }
}

export const recoveryGuardService: RecoveryGuardService = new RecoveryGuardService();
