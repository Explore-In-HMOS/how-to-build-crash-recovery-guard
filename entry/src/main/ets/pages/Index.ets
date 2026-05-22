import { AppNavigator } from './guide/AppNavigator';
import { PageRoutes } from './guide/PageRoutes';
import {
  CrashRecoveryRouteBuilder,
  FreezeGuardRouteBuilder,
  GuideHomeRouteBuilder,
  TimelineRouteBuilder
} from './guide/RouteBuilders';
import { LAUNCH_DID_RESTORE_KEY, LAUNCH_IS_RECOVERY_KEY } from '../models/LaunchRecoveryState';

@Entry({ useSharedStorage: true })
@Component
struct Index {
  private pathStack: NavPathStack = new NavPathStack();
  @LocalStorageProp(LAUNCH_IS_RECOVERY_KEY) launchIsRecovery: boolean = false;
  @LocalStorageProp(LAUNCH_DID_RESTORE_KEY) launchDidRestore: boolean = false;

  aboutToAppear(): void {
    AppNavigator.setPathStack(this.pathStack);
  }

  build() {
    Navigation(this.pathStack) {
    }
    .mode(NavigationMode.Stack)
    .hideNavBar(true)
    .navDestination(this.pageMap)
    .onAppear(() => this.seedInitialRoute())
    .width('100%')
    .height('100%')
    .backgroundColor('#050B16')
  }

  @Builder
  private pageMap(name: string) {
    if (name === PageRoutes.HOME) {
      GuideHomeRouteBuilder();
    } else if (name === PageRoutes.CRASH_RECOVERY) {
      CrashRecoveryRouteBuilder();
    } else if (name === PageRoutes.FREEZE_GUARD) {
      FreezeGuardRouteBuilder();
    } else if (name === PageRoutes.TIMELINE) {
      TimelineRouteBuilder();
    } else {
      GuideHomeRouteBuilder();
    }
  }

  private seedInitialRoute(): void {
    if (this.pathStack.size() === 0) {
      if (this.launchIsRecovery || this.launchDidRestore) {
        this.pathStack.pushPath({ name: PageRoutes.HOME }, false);
        this.pathStack.pushPath({ name: PageRoutes.CRASH_RECOVERY });
      } else {
        this.pathStack.pushPath({ name: PageRoutes.HOME });
      }
    }
  }
}
