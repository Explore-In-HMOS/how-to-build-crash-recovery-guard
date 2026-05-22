import { GUARD_LOOP_DEMO_STATUS_KEY, recoveryGuardService } from '../../services/RecoveryGuardService';

@Component
export struct FreezeGuardPage {
  @LocalStorageProp(GUARD_LOOP_DEMO_STATUS_KEY) loopDemoStatus: string = '';

  build() {
    Column({ space: 10 }) {
      Text('Freeze')
        .fontSize(16).fontWeight(FontWeight.Bold).fontColor('#F7FBFF').textAlign(TextAlign.Center).width('100%')
        .margin({ bottom: 8 })
      Button('Simulate loop timeout')
        .fontSize(10).fontColor('#2B0C0C').backgroundColor('#FDE68A').height(32)
        .width('100%')
        .onClick(() => recoveryGuardService.simulateLoopTimeout())
      if (this.loopDemoStatus.length > 0) {
        Text(this.loopDemoStatus)
          .fontSize(9).fontWeight(FontWeight.Medium).fontColor('#FFF7D6')
          .textAlign(TextAlign.Center).width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .padding({ left: 18, right: 18, top: 18, bottom: 24 })
    .backgroundColor('#050B16')
  }
}
