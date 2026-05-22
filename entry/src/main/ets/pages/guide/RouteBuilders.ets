import { CrashRecoveryPage } from './CrashRecoveryPage';
import { FreezeGuardPage } from './FreezeGuardPage';
import { GuideHomePage } from './GuideHomePage';
import { TimelinePage } from './TimelinePage';

@Builder
export function GuideHomeRouteBuilder() {
  NavDestination() {
    GuideHomePage();
  }
  .hideTitleBar(true)
}

@Builder
export function CrashRecoveryRouteBuilder() {
  NavDestination() {
    CrashRecoveryPage();
  }
  .hideTitleBar(true)
}

@Builder
export function FreezeGuardRouteBuilder() {
  NavDestination() {
    FreezeGuardPage();
  }
  .hideTitleBar(true)
}

@Builder
export function TimelineRouteBuilder() {
  NavDestination() {
    TimelinePage();
  }
  .hideTitleBar(true)
}
