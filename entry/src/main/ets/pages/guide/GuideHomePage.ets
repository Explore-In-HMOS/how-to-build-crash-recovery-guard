import { AppNavigator } from './AppNavigator';
import { PageRoutes } from './PageRoutes';

@Component
export struct GuideHomePage {
  build() {
    Scroll() {
        Column({ space: 8 }) {
          Text('Recovery Guard')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F7FBFF')
            .textAlign(TextAlign.Center)
            .width('100%')

          this.navCard('Recovery', PageRoutes.CRASH_RECOVERY, '#F0ABFC', '#120817')
          this.navCard('Freeze', PageRoutes.FREEZE_GUARD, '#FDE68A', '#2B0C0C')
          this.navCard('Timeline', PageRoutes.TIMELINE, '#7DD3FC', '#08111F')
        }
        .width('100%')
        .padding({ left: 18, right: 18, top: 22, bottom: 24 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#050B16')
    .scrollBar(BarState.Off)
  }

  @Builder
  private navCard(title: string, route: string, color: string, textColor: string) {
    Button() {
      Column({ space: 3 }) {
        Text(title)
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(textColor)
          .textAlign(TextAlign.Center)
      }
      .width('100%')
    }
    .width('100%')
    .padding(10)
    .backgroundColor(color)
    .borderRadius(18)
    .onClick(() => AppNavigator.push(route))
  }
}
