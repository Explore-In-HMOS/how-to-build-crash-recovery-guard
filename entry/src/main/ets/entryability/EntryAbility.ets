import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { RECOVERY_CHECKPOINT_KEY, RECOVERY_MESSAGE_KEY, RecoveryCheckpoint, RecoveryCheckpointHelper } from '../models/RecoveryCheckpoint';
import { IncidentEventHelper } from '../models/IncidentEvent';
import { LAUNCH_DID_RESTORE_KEY, LAUNCH_IS_RECOVERY_KEY, LAUNCH_RECOVERY_STATE_KEY, LaunchRecoveryState, LaunchRecoveryStateHelper } from '../models/LaunchRecoveryState';
import { incidentTimelineStore } from '../services/IncidentTimelineStore';
import { recoveryGuardService } from '../services/RecoveryGuardService';

const DOMAIN: number = 0x0000;
const TAG: string = 'CrashRecoveryGuard';
const DEFAULT_MESSAGE: string = 'Checkpoint 1: baseline';

export default class EntryAbility extends UIAbility {
  private storage: LocalStorage = new LocalStorage();
  private currentCheckpoint: RecoveryCheckpoint = RecoveryCheckpointHelper.createDefault(DEFAULT_MESSAGE);

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    const recoveredCheckpoint: RecoveryCheckpoint | undefined = RecoveryCheckpointHelper.parse(want.parameters);
    const isRecoveryLaunch: boolean = launchParam.launchReason === AbilityConstant.LaunchReason.APP_RECOVERY;
    const didRestore: boolean = isRecoveryLaunch && recoveredCheckpoint !== undefined;
    if (didRestore && recoveredCheckpoint !== undefined) {
      this.currentCheckpoint = recoveredCheckpoint;
    }
    const launchState: LaunchRecoveryState = LaunchRecoveryStateHelper.create(
      isRecoveryLaunch,
      didRestore,
      this.currentCheckpoint,
      IncidentEventHelper.create(launchParam.launchReason, launchParam.lastExitReason, didRestore)
    );
    incidentTimelineStore.bind(this.storage, this.context);
    incidentTimelineStore.addLaunchEvent(launchState.incident);
    recoveryGuardService.bind(this.storage, this.context);
    this.storage.setOrCreate(RECOVERY_MESSAGE_KEY, this.currentCheckpoint.message);
    this.storage.setOrCreate(LAUNCH_IS_RECOVERY_KEY, isRecoveryLaunch);
    this.storage.setOrCreate(LAUNCH_DID_RESTORE_KEY, didRestore);
    this.storage.setOrCreate(LAUNCH_RECOVERY_STATE_KEY, JSON.stringify(launchState));
    hilog.info(DOMAIN, TAG, 'Ability onCreate. recoveryLaunch=%{public}s restored=%{public}s',
      JSON.stringify(isRecoveryLaunch), JSON.stringify(didRestore));
  }

  onSaveState(reason: AbilityConstant.StateType, wantParam: Record<string, Object>): AbilityConstant.OnSaveResult {
    const latestMessage: string | undefined = this.storage.get<string>(RECOVERY_MESSAGE_KEY);
    if (latestMessage !== undefined) {
      this.currentCheckpoint.message = latestMessage;
    }
    this.currentCheckpoint.savedAt = Date.now();
    wantParam[RECOVERY_CHECKPOINT_KEY] = RecoveryCheckpointHelper.serialize(this.currentCheckpoint);
    hilog.info(DOMAIN, TAG, 'onSaveState reason=%{public}d checkpointSavedAt=%{public}d', reason,
      this.currentCheckpoint.savedAt);
    return AbilityConstant.OnSaveResult.RECOVERY_AGREE;
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', this.storage, (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'Succeeded in loading the content.');
      recoveryGuardService.registerLoopObserver();
      if (recoveryGuardService.shouldAutoRegister()) {
        recoveryGuardService.registerObserver();
      }
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageDestroy');
    recoveryGuardService.unregisterObserver();
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    this.currentCheckpoint.savedAt = Date.now();
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onBackground');
  }
}
