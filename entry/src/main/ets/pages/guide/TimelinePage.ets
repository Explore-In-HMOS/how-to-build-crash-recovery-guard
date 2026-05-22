import { IncidentEvent } from '../../models/IncidentEvent';
import { recoveryGuardService } from '../../services/RecoveryGuardService';
import { INCIDENT_TIMELINE_KEY } from '../../services/IncidentTimelineStore';

@Component
export struct TimelinePage {
  @LocalStorageProp(INCIDENT_TIMELINE_KEY) timelineJson: string = '[]';

  private events(): IncidentEvent[] {
    try {
      const parsed: Object = JSON.parse(this.timelineJson) as Object;
      if (!Array.isArray(parsed)) {
        return [];
      }
      return parsed as IncidentEvent[];
    } catch (err) {
      return [];
    }
  }

  build() {
    Scroll() {
        Column({ space: 8 }) {
          Text('Timeline')
            .fontSize(16).fontWeight(FontWeight.Bold).fontColor('#F7FBFF').textAlign(TextAlign.Center).width('100%')

          Column({ space: 6 }) {
            Text('Events')
              .fontSize(12).fontWeight(FontWeight.Bold).fontColor('#F7FBFF')
            if (this.events().length === 0) {
                Text('No events yet.')
                .fontSize(9).fontColor('#C7D3E3').textAlign(TextAlign.Center)
            } else {
              ForEach(this.events(), (item: IncidentEvent) => {
                Text(item.summary)
                  .fontSize(9).fontColor('#D8E0EA').width('100%').padding(6).backgroundColor('#0F172A').borderRadius(10)
              }, (item: IncidentEvent) => item.id)
            }
            Button('Reset demo')
              .fontSize(10).fontColor('#2B0C0C').backgroundColor('#FDA4AF').height(30)
              .onClick(() => recoveryGuardService.resetDemo())
          }.width('100%').padding(10).backgroundColor('#111827').borderRadius(18)

        }.width('100%').padding({ left: 18, right: 18, top: 18, bottom: 24 })
    }.width('100%').height('100%').backgroundColor('#050B16').scrollBar(BarState.Off)
  }
}
