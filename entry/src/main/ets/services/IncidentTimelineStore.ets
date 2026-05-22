import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { IncidentEvent } from '../models/IncidentEvent';

export const INCIDENT_TIMELINE_KEY: string = 'incidentTimeline';
const MAX_EVENTS: number = 8;
const PREFERENCES_NAME: string = 'crash_recovery_guard_timeline';

export class IncidentTimelineStore {
  private storage?: LocalStorage;
  private dataPreferences?: preferences.Preferences;

  bind(storage: LocalStorage, context?: common.UIAbilityContext): void {
    this.storage = storage;
    if (this.storage.get<string>(INCIDENT_TIMELINE_KEY) === undefined) {
      this.storage.setOrCreate(INCIDENT_TIMELINE_KEY, '[]');
    }
    if (context !== undefined && this.dataPreferences === undefined) {
      try {
        const options: preferences.Options = { name: PREFERENCES_NAME };
        this.dataPreferences = preferences.getPreferencesSync(context, options);
        const persisted: preferences.ValueType = this.dataPreferences.getSync(INCIDENT_TIMELINE_KEY, '[]');
        if (typeof persisted === 'string') {
          this.storage?.setOrCreate(INCIDENT_TIMELINE_KEY, persisted);
        }
      } catch (err) {
        this.storage?.setOrCreate(INCIDENT_TIMELINE_KEY, '[]');
      }
    }
  }

  add(summary: string): void {
    this.addEvent(this.createEvent(summary));
  }

  async addAndPersist(summary: string): Promise<void> {
    await this.addEventAndPersist(this.createEvent(summary));
  }

  private createEvent(summary: string): IncidentEvent {
    return {
      id: `incidents-${Date.now()}`,
      occurredAt: Date.now(),
      launchReason: -1,
      lastExitReason: -1,
      restored: false,
      summary: summary
    };
  }

  addLaunchEvent(event: IncidentEvent): void {
    this.addEvent(event);
  }

  clear(): void {
    this.write([]);
  }

  resetWithEvent(summary: string): void {
    this.writeSync([this.createEvent(summary)]);
  }

  getEvents(): IncidentEvent[] {
    const raw: string | undefined = this.storage?.get<string>(INCIDENT_TIMELINE_KEY);
    if (raw === undefined || raw.length === 0) {
      return [];
    }
    try {
      const parsed: Object = JSON.parse(raw) as Object;
      if (!Array.isArray(parsed)) {
        return [];
      }
      const events: IncidentEvent[] = [];
      parsed.forEach((item: Object) => {
        if (this.isIncidentEvent(item)) {
          events.push(item as IncidentEvent);
        }
      });
      return events.slice(0, MAX_EVENTS);
    } catch (err) {
      return [];
    }
  }

  private write(events: IncidentEvent[]): void {
    if (this.storage === undefined) {
      return;
    }
    const raw: string = JSON.stringify(events);
    this.storage.setOrCreate(INCIDENT_TIMELINE_KEY, raw);
    if (this.dataPreferences !== undefined) {
      this.dataPreferences.put(INCIDENT_TIMELINE_KEY, raw).then(() => {
        this.dataPreferences?.flush();
      }).catch(() => {
      });
    }
  }

  private writeSync(events: IncidentEvent[]): void {
    if (this.storage === undefined) {
      return;
    }
    const raw: string = JSON.stringify(events);
    this.storage.setOrCreate(INCIDENT_TIMELINE_KEY, raw);
    if (this.dataPreferences !== undefined) {
      try {
        this.dataPreferences.putSync(INCIDENT_TIMELINE_KEY, raw);
        this.dataPreferences.flushSync();
      } catch (err) {
      }
    }
  }

  private addEvent(event: IncidentEvent): void {
    const next: IncidentEvent[] = [event].concat(this.getEvents()).slice(0, MAX_EVENTS);
    this.write(next);
  }

  private async addEventAndPersist(event: IncidentEvent): Promise<void> {
    const next: IncidentEvent[] = [event].concat(this.getEvents()).slice(0, MAX_EVENTS);
    const raw: string = JSON.stringify(next);
    this.storage?.setOrCreate(INCIDENT_TIMELINE_KEY, raw);
    if (this.dataPreferences !== undefined) {
      try {
        await this.dataPreferences.put(INCIDENT_TIMELINE_KEY, raw);
        await this.dataPreferences.flush();
      } catch (err) {
      }
    }
  }

  private isIncidentEvent(value: Object): boolean {
    if (typeof value !== 'object' || value === null || Array.isArray(value)) {
      return false;
    }
    const record: Record<string, Object> = value as Record<string, Object>;
    return typeof record?.id === 'string' && typeof record?.occurredAt === 'number' &&
      typeof record?.summary === 'string';
  }
}

export const incidentTimelineStore: IncidentTimelineStore = new IncidentTimelineStore();
