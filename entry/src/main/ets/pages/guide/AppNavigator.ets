import { PageRoutes } from './PageRoutes';

export class AppNavigator {
  private static readonly PATH_STACK_KEY: string = 'recoveryGuardNavPathStack';

  static setPathStack(pathStack: NavPathStack): void {
    AppStorage.setOrCreate<NavPathStack>(AppNavigator.PATH_STACK_KEY, pathStack);
  }

  static push(routeName: string): void {
    const pathStack = AppNavigator.getPathStack();
    if (!pathStack) {
      return;
    }
    pathStack.pushPath({ name: routeName });
  }

  static pop(): void {
    const pathStack = AppNavigator.getPathStack();
    if (!pathStack) {
      return;
    }
    pathStack.pop();
  }

  static goHome(): void {
    const pathStack = AppNavigator.getPathStack();
    if (!pathStack) {
      return;
    }
    pathStack.clear();
    pathStack.pushPath({ name: PageRoutes.HOME });
  }

  private static getPathStack(): NavPathStack | undefined {
    return AppStorage.get<NavPathStack>(AppNavigator.PATH_STACK_KEY);
  }
}
