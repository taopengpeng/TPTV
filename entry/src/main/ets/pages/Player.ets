import { media } from '@kit.MediaKit';
import { common } from '@kit.AbilityKit';
import { router, window } from '@kit.ArkUI';
import { BusinessError, deviceInfo } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { VideoItem } from '../model/VideoItem';
import { LiveChannel } from '../model/LiveChannel';
import { LiveStore } from '../model/LiveStore';
import { ChannelFilter } from '../model/ChannelFilter';
import { FavoriteStore } from '../data/FavoriteStore';
import { EpgService } from '../data/EpgService';

const TAG: string = 'PlayerPage';
const DOMAIN: number = 0x0000;
const KEY_DPAD_UP: number = 2012;
const KEY_DPAD_DOWN: number = 2013;

@Entry
@Component
struct Player {
  @State isPlaying: boolean = false;
  @State currentTime: number = 0;
  @State duration: number = 0;
  @State isDragging: boolean = false;
  @State isLoading: boolean = true;
  @State errorMsg: string = '';
  @State isLive: boolean = false;
  @State channelName: string = '';
  @State srcIndex: number = 0;
  @State srcTotal: number = 1;
  @State epgNow: string = '';
  @State title: string = '视频播放';
  @State isFullscreen: boolean = false;
  @State showControls: boolean = true;
  @State playerWidth: number = 0;
  @State playerHeight: number = 0;
  @State videoRatio: number = 16 / 9;
  @State controlLeft: number = 0;
  @State controlTop: number = 0;
  @State controlRight: number = 0;
  @State controlBottom: number = 0;
  private playerWindow: window.Window | null = null;
  private windowUpdates: Promise<void> = Promise.resolve();
  private rawFile: string = '';
  private url: string = '';
  private xController: XComponentController = new XComponentController();
  private avPlayer: media.AVPlayer | null = null;
  private failCount: number = 0;
  private prepareTimer: number = -1;
  /** 当前频道的全部源（主源 + 备源），供手动/自动切源 */
  private srcList: LiveChannel[] = [];
  private triedUrls: Set<string> = new Set<string>();

  aboutToAppear(): void {
    const params = router.getParams() as VideoItem;
    if (params) {
      this.title = params.title;
      this.rawFile = params.rawFile;
      this.url = params.url;
      this.isLive = params.isLive;
      this.channelName = params.title;
    }
    this.keepScreenOn(true);
    if (this.isLive) {
      this.initSourceList();
    }
    if (deviceInfo.deviceType !== 'tv') {
      this.setOrientation(window.Orientation.PORTRAIT);
    }
  }

  /** 组装当前频道的源列表（主源 + 备源），供手动/自动切源；无备源时从完整源目录按同名补齐 */
  private initSourceList(): void {
    const key = ChannelFilter.normalizeKey(this.channelName);
    let primary: LiveChannel | undefined = undefined;
    for (const ch of LiveStore.channels) {
      if (ChannelFilter.normalizeKey(ch.name) === key) {
        primary = ch;
        break;
      }
    }
    if (!primary) {
      this.srcList = [new LiveChannel(this.channelName, this.url, '')];
    } else if (primary.alts.length > 0) {
      this.srcList = [primary, ...primary.alts];
    } else {
      const extra: LiveChannel[] = [];
      for (const ch of LiveStore.fullChannels) {
        if (ch.url !== primary.url && ChannelFilter.normalizeKey(ch.name) === key) {
          extra.push(ch);
          if (extra.length >= 4) {
            break;
          }
        }
      }
      this.srcList = [primary, ...extra];
    }
    this.srcTotal = this.srcList.length;
    this.srcIndex = 0;
    this.triedUrls = new Set<string>();
    this.triedUrls.add(this.url);
    if (this.isLive && this.srcList.length > 0) {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      FavoriteStore.addHistory(context, this.srcList[0]);
      const epg = EpgService.current(this.channelName);
      this.epgNow = epg.ok ? `正在播：${epg.nowTitle}` : '';
    }
  }

  aboutToDisappear(): void {
    this.keepScreenOn(false);
    this.clearPrepareTimer();
    if (deviceInfo.deviceType !== 'tv') {
      this.setOrientation(window.Orientation.UNSPECIFIED);
    }
    this.releasePlayer();
  }

  onBackPress(): boolean {
    if (this.isFullscreen) {
      this.toggleFullscreen();
      return true;
    }
    return false;
  }

  /** 全屏开关：手机端全屏 = 横屏 + 沉浸式隐藏控制栏；TV 端本就是全屏横屏 */
  private toggleFullscreen(): void {
    this.isFullscreen = !this.isFullscreen;
    this.showControls = !this.isFullscreen;
    if (deviceInfo.deviceType === 'tv') {
      return;
    }
    this.setOrientation(this.isFullscreen ? window.Orientation.LANDSCAPE : window.Orientation.PORTRAIT,
      this.isFullscreen);
  }

  private setOrientation(orientation: window.Orientation, fullscreen: boolean = false): void {
    const context = this.getUIContext().getHostContext();
    if (!context) {
      return;
    }
    this.windowUpdates = this.windowUpdates.then(async () => {
      const win = await window.getLastWindow(context);
      this.playerWindow = win;
      await win.setPreferredOrientation(orientation);
      await win.setWindowLayoutFullScreen(fullscreen);
      await win.setWindowSystemBarEnable(fullscreen ? [] : ['status', 'navigation']);
      this.updateControlInsets();
    }).catch((err: BusinessError) => {
      hilog.error(DOMAIN, TAG, 'update player window failed: %{public}d', err.code);
    });
  }

  private updateControlInsets(): void {
    if (!this.playerWindow || !this.isFullscreen) {
      this.controlLeft = 0;
      this.controlTop = 0;
      this.controlRight = 0;
      this.controlBottom = 0;
      return;
    }
    const cutout = this.playerWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT);
    const navigation = this.playerWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
    const uiContext = this.getUIContext();
    this.controlLeft = uiContext.px2vp(Math.max(cutout.leftRect.width, navigation.leftRect.width));
    this.controlTop = uiContext.px2vp(Math.max(cutout.topRect.height, navigation.topRect.height));
    this.controlRight = uiContext.px2vp(Math.max(cutout.rightRect.width, navigation.rightRect.width));
    this.controlBottom = uiContext.px2vp(Math.max(cutout.bottomRect.height, navigation.bottomRect.height));
  }

  @Builder
  private iconButton(icon: Resource, label: string, action: () => void) {
    Button({ type: ButtonType.Normal }) {
      SymbolGlyph(icon)
        .fontSize(24)
        .fontColor(['#FFFFFF'])
    }
    .width(48)
    .height(48)
    .padding(12)
    .borderRadius(8)
    .backgroundColor('#33000000')
    .accessibilityText(label)
    .onClick(() => {
      action();
    })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        XComponent({ id: 'video_surface', type: 'surface', controller: this.xController })
          .width(deviceInfo.deviceType !== 'tv' && this.playerWidth > 0 && this.playerHeight > 0 ?
            Math.min(this.playerWidth, this.playerHeight * this.videoRatio) : '100%')
          .height(deviceInfo.deviceType !== 'tv' && this.playerWidth > 0 && this.playerHeight > 0 ?
            Math.min(this.playerWidth / this.videoRatio, this.playerHeight) : '100%')
          .onLoad(() => {
            const surfaceId: string = this.xController.getXComponentSurfaceId();
            this.initPlayer(surfaceId);
          })
          .onAreaChange((oldArea: Area, newArea: Area) => {
            const uiContext = this.getUIContext();
            const width = Math.round(uiContext.vp2px(Number(newArea.width)));
            const height = Math.round(uiContext.vp2px(Number(newArea.height)));
            if (width > 0 && height > 0) {
              this.xController.setXComponentSurfaceRect({ surfaceWidth: width, surfaceHeight: height });
            }
          })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .onClick(() => {
        this.showControls = !this.showControls;
      })

      if (this.showControls) {
        Column() {
          // 顶部标题栏
          Row({ space: 8 }) {
            this.iconButton($r('sys.symbol.chevron_left'), '返回', () => {
              if (!this.onBackPress()) {
                router.back();
              }
            })
            Column({ space: 2 }) {
              Text(this.title)
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .fontColor('#F0FFFFFF')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              if (this.isLive && this.epgNow !== '') {
                Text(this.epgNow)
                  .fontSize(12)
                  .fontColor('#99FFFFFF')
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            if (this.isLive) {
              Text('直播')
                .fontSize(12)
                .fontColor('#FF5A5A')
            }
            this.iconButton(this.isFullscreen ? $r('sys.symbol.arrow_down_right_and_arrow_up_left') :
              $r('sys.symbol.arrow_up_left_and_arrow_down_right'), this.isFullscreen ? '退出全屏' : '全屏', () => {
                this.toggleFullscreen();
              })
          }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        .padding({ left: 12 + this.controlLeft, right: 12 + this.controlRight,
          top: 12 + this.controlTop, bottom: 12 })
        .linearGradient({ angle: 180, colors: [['#CC000000', 0], ['#00000000', 1]] })

        Blank()
          .hitTestBehavior(HitTestMode.None)

        // 底部控制栏：直播为换台控制，点播为进度控制
        if (this.isLive) {
          Row({ space: 8 }) {
            this.iconButton($r('sys.symbol.backward_end_fill'), '上一频道', () => {
                this.switchChannel(-1);
              })
            this.iconButton(this.isPlaying ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'),
              this.isPlaying ? '暂停' : '播放', () => {
                this.togglePlay();
              })
            this.iconButton($r('sys.symbol.forward_end_fill'), '下一频道', () => {
                this.switchChannel(1);
              })
            Button({ type: ButtonType.Normal }) {
              Text(`线路 ${this.srcIndex + 1}/${this.srcTotal}`)
                .fontSize(14)
                .fontColor('#FFFFFF')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
              .backgroundColor('#66000000')
              .fontSize(14)
              .height(48)
              .layoutWeight(1)
              .padding({ left: 8, right: 8 })
              .borderRadius(8)
              .enabled(this.srcTotal > 1)
              .accessibilityText(`切换线路，当前 ${this.srcIndex + 1}/${this.srcTotal}`)
              .onClick(() => {
                this.manualNextSource();
              })
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          .justifyContent(FlexAlign.Center)
          .constraintSize({ maxWidth: 420 + this.controlLeft + this.controlRight })
          .alignSelf(ItemAlign.Center)
          .padding({ left: 16 + this.controlLeft, right: 16 + this.controlRight,
            top: 12, bottom: 16 + this.controlBottom })
          .linearGradient({ angle: 0, colors: [['#CC000000', 0], ['#00000000', 1]] })
        } else {
          Row({ space: 16 }) {
            this.iconButton(this.isPlaying ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'),
              this.isPlaying ? '暂停' : '播放', () => {
                this.togglePlay();
              })

            Text(this.formatTime(this.currentTime))
              .fontSize(14)
              .fontColor('#CCFFFFFF')

            Slider({
              value: this.currentTime,
              min: 0,
              max: this.duration > 0 ? this.duration : 1,
              step: 500,
              style: SliderStyle.OutSet
            })
              .layoutWeight(1)
              .onChange((value: number, mode: SliderChangeMode) => {
                if (mode === SliderChangeMode.Begin) {
                  this.isDragging = true;
                }
                if (mode === SliderChangeMode.Moving) {
                  this.currentTime = value;
                }
                if (mode === SliderChangeMode.End) {
                  this.currentTime = value;
                  this.isDragging = false;
                  this.avPlayer?.seek(Math.floor(value), media.SeekMode.SEEK_PREV_SYNC);
                }
              })

            Text(this.formatTime(this.duration))
              .fontSize(14)
              .fontColor('#CCFFFFFF')
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          .padding({ left: 16 + this.controlLeft, right: 16 + this.controlRight,
            top: 12, bottom: 16 + this.controlBottom })
          .linearGradient({ angle: 0, colors: [['#CC000000', 0], ['#00000000', 1]] })
        }
      }
      .width('100%')
      .height('100%')
      .hitTestBehavior(HitTestMode.None)
      }

      // 加载中 / 播放失败提示（在线视频缓冲时可见）；不拦截遥控器外的点击
      Column() {
        if (this.errorMsg !== '') {
          Text(this.errorMsg)
            .fontSize(18)
            .fontColor('#FFDDDD')
            .padding({ left: 16, right: 16, top: 10, bottom: 10 })
            .borderRadius(8)
            .backgroundColor('#66000000')
        } else if (this.isLoading) {
          Text('加载中…')
            .fontSize(20)
            .fontColor('#F0FFFFFF')
            .padding({ left: 16, right: 16, top: 10, bottom: 10 })
            .borderRadius(8)
            .backgroundColor('#66000000')
        }
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .hitTestBehavior(HitTestMode.None)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
    .onAreaChange((oldArea: Area, newArea: Area) => {
      this.playerWidth = Number(newArea.width);
      this.playerHeight = Number(newArea.height);
      this.updateControlInsets();
    })
    .onKeyEvent((event: KeyEvent) => {
      if (event.type !== KeyType.Down || !this.isLive) {
        return;
      }
      if (event.keyCode === KEY_DPAD_UP) {
        this.switchChannel(-1);
      } else if (event.keyCode === KEY_DPAD_DOWN) {
        this.switchChannel(1);
      }
    })
  }

  /**
   * 对应旧版 VideoView.playAssets(...)：播放 rawfile 中的视频资源。
   * 旧实现基于 ohos.media.player.Player + SurfaceProvider，
   * Stage 模型下改用 AVPlayer + XComponent(surface)。
   */
  private async initPlayer(surfaceId: string): Promise<void> {
    try {
      const avPlayer: media.AVPlayer = await media.createAVPlayer();
      this.avPlayer = avPlayer;

      avPlayer.on('stateChange', (state: media.AVPlayerState) => {
        hilog.info(DOMAIN, TAG, 'stateChange: %{public}s', state);
        if (state === 'initialized') {
          avPlayer.surfaceId = surfaceId;
          avPlayer.prepare().catch((err: BusinessError) => {
            hilog.error(DOMAIN, TAG, 'prepare failed: %{public}d %{public}s', err.code, err.message);
          });
        } else if (state === 'prepared') {
          // 保持宽高比渲染（letterbox），避免画面被拉伸。
          // 注意：videoScaleType 仅允许在 prepared/playing/paused/completed 状态设置
          avPlayer.videoScaleType = media.VideoScaleType.VIDEO_SCALE_TYPE_FIT;
          if (avPlayer.width > 0 && avPlayer.height > 0) {
            this.videoRatio = avPlayer.width / avPlayer.height;
          }
          this.failCount = 0;
          this.clearPrepareTimer();
          // loop 仅允许在 prepared/playing/paused/completed 状态设置（idle 下设置报 5400102）
          if (!this.isLive) {
            this.duration = avPlayer.duration;
            avPlayer.loop = true;
          }
          this.isLoading = false;
          avPlayer.play();
        } else if (state === 'playing') {
          this.isPlaying = true;
        } else if (state === 'paused' || state === 'completed') {
          this.isPlaying = false;
        }
      });

      avPlayer.on('videoSizeChange', (width: number, height: number) => {
        if (width > 0 && height > 0) {
          this.videoRatio = width / height;
        }
      });

      avPlayer.on('timeUpdate', (time: number) => {
        if (!this.isDragging) {
          this.currentTime = time;
        }
      });

      avPlayer.on('error', (err: BusinessError) => {
        hilog.error(DOMAIN, TAG, 'player error: %{public}d %{public}s', err.code, err.message);
        if (this.isLive) {
          // 直播源失效是常态：自动切到同名频道的下一条源
          this.autoSwitchSource(`流错误(${err.code})`);
        } else {
          this.isLoading = false;
          this.errorMsg = `播放失败(${err.code}: ${err.message})`;
        }
      });

      // 视频源：在线 url 流式播放（对应旧版注释里的 setSource(new Source("http://..."))），
      // 或本地 rawfile 资源（等价旧版 getRawFileEntry(...).openRawFileDescriptor()）
      if (this.url !== '') {
        avPlayer.url = this.url;
      } else {
        const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
        avPlayer.fdSrc = context.resourceManager.getRawFdSync(this.rawFile);
      }
      // 循环在 prepared 回调中按模式开启（idle 状态设置会报 5400102）；对应旧版 enableScreenOn(true)
    } catch (err) {
      const e = err as BusinessError;
      hilog.error(DOMAIN, TAG, 'initPlayer failed: %{public}d %{public}s', e.code, e.message);
      this.isLoading = false;
      this.errorMsg = `播放器初始化失败(${e.code})`;
    }
  }

  /** 直播模式：循环换台（按钮与遥控器上/下键共用） */
  private switchChannel(delta: number): void {
    const channels = LiveStore.channels;
    if (!this.isLive || channels.length === 0) {
      return;
    }
    const next = (LiveStore.currentIndex + delta + channels.length) % channels.length;
    this.playChannelAt(next);
  }

  /** 失效自动换源：在当前频道的源列表里找一条没试过的，连续失败 5 次后放弃 */
  private autoSwitchSource(reason: string): void {
    if (this.failCount >= 5 || this.srcList.length === 0) {
      this.isLoading = false;
      this.errorMsg = `该频道多条源均不可用（最后原因：${reason}）`;
      return;
    }
    for (let i = 0; i < this.srcList.length; i++) {
      const src = this.srcList[i];
      if (src.url !== this.url && !this.triedUrls.has(src.url)) {
        hilog.info(DOMAIN, TAG, 'auto switch source -> %{public}s (%{public}s)', src.url, reason);
        this.playSource(i);
        return;
      }
    }
    this.isLoading = false;
    this.errorMsg = `播放失败：${reason}，且无备用源`;
  }

  /** 手动切换播放源（在主源与备源间循环） */
  private manualNextSource(): void {
    if (!this.isLive || this.srcList.length < 2) {
      return;
    }
    const next = (this.srcIndex + 1) % this.srcList.length;
    this.playSource(next);
  }

  private playChannelAt(index: number): void {
    const channels = LiveStore.channels;
    const ch = channels[index];
    if (!ch) {
      return;
    }
    LiveStore.currentIndex = index;
    this.channelName = ch.name;
    this.title = ch.name;
    this.srcList = [ch, ...ch.alts];
    this.srcTotal = this.srcList.length;
    this.triedUrls = new Set<string>();
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    FavoriteStore.addHistory(context, ch);
    const epg = EpgService.current(ch.name);
    this.epgNow = epg.ok ? `正在播：${epg.nowTitle}` : '';
    this.playSource(0);
  }

  /** 播放指定序号的源（带 10 秒起播看门狗，超时自动换源） */
  private playSource(index: number): void {
    const src = this.srcList[index];
    if (!src) {
      return;
    }
    this.failCount++;
    this.srcIndex = index;
    this.url = src.url;
    this.isPlaying = false;
    this.isLoading = true;
    this.errorMsg = '';
    this.videoRatio = 16 / 9;
    this.triedUrls.add(src.url);
    this.releasePlayer();
    this.clearPrepareTimer();
    this.prepareTimer = setTimeout(() => {
      if (this.isLoading && this.isLive) {
        this.autoSwitchSource('起播超时10s');
      }
    }, 10000);
    const surfaceId: string = this.xController.getXComponentSurfaceId();
    this.initPlayer(surfaceId);
  }

  private clearPrepareTimer(): void {
    if (this.prepareTimer !== -1) {
      clearTimeout(this.prepareTimer);
      this.prepareTimer = -1;
    }
  }

  private togglePlay(): void {
    const player = this.avPlayer;
    if (!player) {
      return;
    }
    const state = player.state;
    if (state === 'playing') {
      player.pause();
    } else if (state === 'prepared' || state === 'paused' || state === 'completed') {
      player.play();
    }
  }

  private releasePlayer(): void {
    const player = this.avPlayer;
    this.avPlayer = null;
    if (!player) {
      return;
    }
    player.off('stateChange');
    player.off('videoSizeChange');
    player.off('timeUpdate');
    player.off('error');
    player.release().catch((err: BusinessError) => {
      hilog.error(DOMAIN, TAG, 'release failed: %{public}d', err.code);
    });
  }

  private keepScreenOn(keepOn: boolean): void {
    const context = this.getUIContext().getHostContext();
    if (!context) {
      return;
    }
    window.getLastWindow(context).then((win: window.Window) => {
      win.setWindowKeepScreenOn(keepOn);
    }).catch((err: BusinessError) => {
      hilog.error(DOMAIN, TAG, 'setWindowKeepScreenOn failed: %{public}d', err.code);
    });
  }

  private formatTime(ms: number): string {
    const totalSeconds: number = Math.floor(ms / 1000);
    const minutes: number = Math.floor(totalSeconds / 60);
    const seconds: number = totalSeconds % 60;
    return `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
  }
}
