export interface IncidentEvent {
  id: string;
  occurredAt: number;
  launchReason: number;
  lastExitReason: number;
  restored: boolean;
  summary: string;
}

export class IncidentEventHelper {
  static create(launchReason: number, lastExitReason: number, restored: boolean): IncidentEvent {
    const occurredAt: number = Date.now();
    return {
      id: `incident-${occurredAt}`,
      occurredAt: occurredAt,
      launchReason: launchReason,
      lastExitReason: lastExitReason,
      restored: restored,
      summary: restored ? 'Recovered checkpoint after fault restart.' : 'Started without recovered checkpoint.'
    };
  }
}
