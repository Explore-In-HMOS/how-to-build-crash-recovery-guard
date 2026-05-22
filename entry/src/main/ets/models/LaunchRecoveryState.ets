import { RecoveryCheckpoint } from './RecoveryCheckpoint';
import { IncidentEvent } from './IncidentEvent';

export const LAUNCH_RECOVERY_STATE_KEY: string = 'launchRecoveryState';
export const LAUNCH_IS_RECOVERY_KEY: string = 'launchIsRecovery';
export const LAUNCH_DID_RESTORE_KEY: string = 'launchDidRestore';

export interface LaunchRecoveryState {
  isRecoveryLaunch: boolean;
  didRestore: boolean;
  checkpoint: RecoveryCheckpoint;
  incident: IncidentEvent;
}

export class LaunchRecoveryStateHelper {
  static create(isRecoveryLaunch: boolean, didRestore: boolean, checkpoint: RecoveryCheckpoint,
    incident: IncidentEvent): LaunchRecoveryState {
    return {
      isRecoveryLaunch: isRecoveryLaunch,
      didRestore: didRestore,
      checkpoint: checkpoint,
      incident: incident
    };
  }
}
