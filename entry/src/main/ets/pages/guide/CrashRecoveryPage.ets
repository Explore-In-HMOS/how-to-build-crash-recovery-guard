import { RECOVERY_MESSAGE_KEY } from '../../models/RecoveryCheckpoint';
import { LAUNCH_DID_RESTORE_KEY, LAUNCH_IS_RECOVERY_KEY } from '../../models/LaunchRecoveryState';
import {
  GUARD_CAPTURE_ENABLED_KEY,
  GUARD_FEEDBACK_KEY,
  GUARD_LAST_RESTART_AT_KEY,
  recoveryGuardService
} from '../../services/RecoveryGuardService';

const PRESETS: string[] = ['Checkpoint 1: baseline', 'Checkpoint 2: form draft', 'Checkpoint 3: review ready'];

@Component
export struct CrashRecoveryPage {
  @LocalStorageLink(RECOVERY_MESSAGE_KEY) message: string = PRESETS[0];
  @LocalStorageProp(GUARD_FEEDBACK_KEY) feedback: string = 'Guard ready';
  @LocalStorageLink(GUARD_CAPTURE_ENABLED_KEY) captureEnabled: boolean = true;
  @LocalStorageProp(GUARD_LAST_RESTART_AT_KEY) lastRestartAt: number = 0;
  @LocalStorageProp(LAUNCH_IS_RECOVERY_KEY) launchIsRecovery: boolean = false;
  @LocalStorageProp(LAUNCH_DID_RESTORE_KEY) launchDidRestore: boolean = false;
  @State checkpointIndex: number = 0;
  @State changeCount: number = 0;
  @State nowMs: number = Date.now();
  private cooldownTimerId: number = -1;

  aboutToAppear(): void {
    this.nowMs = Date.now();
    if (this.cooldownTimerId < 0) {
      this.cooldownTimerId = setInterval(() => this.nowMs = Date.now(), 1000);
    }
  }

  aboutToDisappear(): void {
    if (this.cooldownTimerId >= 0) {
      clearInterval(this.cooldownTimerId);
      this.cooldownTimerId = -1;
    }
  }

  private changeState(): void {
    this.changeCount += 1;
    this.checkpointIndex = (this.checkpointIndex + 1) % PRESETS.length;
    this.message = `${PRESETS[this.checkpointIndex]} #${this.changeCount}`;
  }

  private canRestart(): boolean {
    return this.nowMs - this.lastRestartAt >= 60000;
  }

  private cooldownText(): string {
    const remaining: number = Math.max(0, 60000 - (this.nowMs - this.lastRestartAt));
    if (remaining === 0) {
      return 'Trigger JS error';
    }
    return `Try again ${Math.ceil(remaining / 1000)}s`;
  }

  private jsErrorText(): string {
    if (!this.captureEnabled || this.canRestart()) {
      return 'Trigger JS error';
    }
    return this.cooldownText();
  }

  private restoreText(): string {
    if (this.launchIsRecovery && this.launchDidRestore) {
      return 'Recovered last checkpoint.';
    }
    return 'Last launch was normal.';
  }

  build() {
    Scroll() {
        Column({ space: 8 }) {
          Text('Recovery')
            .fontSize(16).fontWeight(FontWeight.Bold).fontColor('#F7FBFF').textAlign(TextAlign.Center).width('100%')
          Column({ space: 5 }) {
            Text('Checkpoint')
              .fontSize(12).fontWeight(FontWeight.Bold).fontColor('#F7FBFF')
            Text(this.message)
              .fontSize(10).fontColor('#C7D3E3').textAlign(TextAlign.Center)
            this.smallButton('Change state', '#7DD3FC', '#08111F', () => this.changeState())
          }.width('100%').padding(10).backgroundColor('#111827').borderRadius(18)

          Column({ space: 6 }) {
            Text(this.captureEnabled ? 'Observer save on' : 'Observer save off')
              .fontSize(12).fontWeight(FontWeight.Bold).fontColor('#F7FBFF')
            Text(this.captureEnabled ? 'Observer logs, saves, and requests restart.' : 'Platform recovery stays enabled.')
              .fontSize(9).fontColor('#D8E0EA').textAlign(TextAlign.Center)
            Button(this.captureEnabled ? 'Turn off' : 'Turn on')
              .fontSize(10)
              .fontColor(this.captureEnabled ? '#D8E0EA' : '#08111F')
              .backgroundColor(this.captureEnabled ? '#2B3445' : '#8EF0A7')
              .height(30)
              .onClick(() => {
                if (this.captureEnabled) {
                  recoveryGuardService.disableCrashGuard();
                } else {
                  recoveryGuardService.enableCrashGuard();
                }
              })
            Button(this.jsErrorText())
              .fontSize(10)
              .fontColor((!this.captureEnabled || this.canRestart()) ? '#120817' : '#D8E0EA')
              .backgroundColor((!this.captureEnabled || this.canRestart()) ? '#F0ABFC' : '#2B3445')
              .height(32)
              .onClick(() => recoveryGuardService.triggerJsErrorTest())
            Text(this.restoreText())
              .fontSize(9).fontColor('#D8E0EA').textAlign(TextAlign.Center)
            Text(`Status: ${this.feedback}`)
              .fontSize(9).fontColor('#AAB7C7').textAlign(TextAlign.Center)
          }.width('100%').padding(10).backgroundColor('#172033').borderRadius(18)

        }.width('100%').padding({ left: 18, right: 18, top: 18, bottom: 24 })
    }.width('100%').height('100%').backgroundColor('#050B16').scrollBar(BarState.Off)
  }

  @Builder private smallButton(label: string, color: string, textColor: string, action: () => void) {
    Button(label).fontSize(10).fontColor(textColor).backgroundColor(color).height(30).onClick(action)
  }
}
