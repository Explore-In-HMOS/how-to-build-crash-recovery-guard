import { AbilityStage, appRecovery } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0000;
const TAG: string = 'CrashRecoveryGuard';

export default class AppAbilityStage extends AbilityStage {
  onCreate(): void {
    appRecovery.enableAppRecovery(
      appRecovery.RestartFlag.ALWAYS_RESTART,
      appRecovery.SaveOccasionFlag.SAVE_WHEN_ERROR,
      appRecovery.SaveModeFlag.SAVE_WITH_FILE
    );
    hilog.info(DOMAIN, TAG, 'Application recovery restart and state saving enabled.');
  }
}
