export const RECOVERY_CHECKPOINT_KEY: string = 'recoveryCheckpoint';
export const RECOVERY_MESSAGE_KEY: string = 'recoveryMessage';

export interface RecoveryCheckpoint {
  schemaVersion: number;
  savedAt: number;
  message: string;
}

export class RecoveryCheckpointHelper {
  static createDefault(message: string): RecoveryCheckpoint {
    return {
      schemaVersion: 1,
      savedAt: Date.now(),
      message: message
    };
  }

  static serialize(checkpoint: RecoveryCheckpoint): string {
    return JSON.stringify(checkpoint);
  }

  static parse(parameters: Record<string, Object> | undefined): RecoveryCheckpoint | undefined {
    if (parameters === undefined) {
      return undefined;
    }
    const rawValue: Object | undefined = parameters[RECOVERY_CHECKPOINT_KEY];
    if (typeof rawValue !== 'string') {
      return undefined;
    }

    let parsed: Object;
    try {
      parsed = JSON.parse(rawValue) as Object;
    } catch (err) {
      return undefined;
    }

    if (!RecoveryCheckpointHelper.isRecord(parsed)) {
      return undefined;
    }

    const record: Record<string, Object> = parsed as Record<string, Object>;
    const schemaVersion: Object | undefined = record?.schemaVersion;
    const savedAt: Object | undefined = record?.savedAt;
    const message: Object | undefined = record?.message;

    if (typeof schemaVersion !== 'number' || typeof savedAt !== 'number' || typeof message !== 'string') {
      return undefined;
    }

    return {
      schemaVersion: schemaVersion,
      savedAt: savedAt,
      message: message
    };
  }

  private static isRecord(value: Object): boolean {
    return typeof value === 'object' && value !== null && !Array.isArray(value);
  }
}
