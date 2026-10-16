import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

const DOMAIN: number = 0x0000;
const TAG: string = 'EntryAbility';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageCreate');
    // 设备分流：TV 直接进入选台页并自动开播，手机/平板进入点播列表首页
    const homePage: string = deviceInfo.deviceType === 'tv' ? 'pages/TvLive' : 'pages/Index';
    hilog.info(DOMAIN, TAG, 'deviceType=%{public}s, home=%{public}s', deviceInfo.deviceType, homePage);
    windowStage.loadContent(homePage, async (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load the content. Cause: %{public}s', JSON.stringify(err) ?? '');
        return;
      }
      // 手机/平板默认竖屏（TV 保持横屏）；播放页全屏时再临时切横屏
      if (deviceInfo.deviceType !== 'tv') {
        try {
          const mainWindow = await windowStage.getMainWindow();
          mainWindow.setWindowBackgroundColor('#000000');
          await mainWindow.setWindowSystemBarProperties({
            statusBarColor: '#000000',
            navigationBarColor: '#000000',
            statusBarContentColor: '#FFFFFF',
            navigationBarContentColor: '#FFFFFF'
          });
          await mainWindow.setPreferredOrientation(window.Orientation.PORTRAIT);
        } catch (e) {
          hilog.error(DOMAIN, TAG, 'setPreferredOrientation failed: %{public}d', (e as BusinessError).code);
        }
      }
      hilog.info(DOMAIN, TAG, 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onBackground');
  }
}
