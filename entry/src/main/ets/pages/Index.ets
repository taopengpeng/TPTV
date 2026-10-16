import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { VideoItem } from '../model/VideoItem';
import { VideoStore } from '../data/VideoStore';
import { LiveCatalog } from '../data/LiveCatalog';

const TAG: string = 'IndexPage';
const DOMAIN: number = 0x0000;
const DISCLAIMER_PREF: string = 'appSettings';
// key 带版本号：声明内容更新后可换 v3 重新弹出；同时避免历史脏数据干扰
const KEY_DISCLAIMER: string = 'disclaimer_agreed_v2';

// 点播片源：仅保留本地 rawfile 视频（离线可用）；自定义片源存 preferences，由 VideoStore 管理。
// 原在线公共测试片源已移除，直播能力见 Live 页。
const BUILTIN_VIDEOS: VideoItem[] = [
  VideoItem.local('本地演示视频', 'video.mp4', '内置 rawfile · 离线可用')
];

// 旧版启动时请求 api.apiopen.top 的 getJoke 接口渲染列表，该接口已下线（返回 HTML）；
// 现为内置本地视频 + 用户自定义片源，接入自有后端后扩展此数组即可。
@Entry
@Component
struct Index {
  @State videoList: VideoItem[] = BUILTIN_VIDEOS;
  @State showAdd: boolean = false;
  @State inputTitle: string = '';
  @State inputUrl: string = '';
  @State disclaimerAccepted: boolean = false;
  @State showTests: boolean = false;
  @State brandFont: string = 'HarmonyOS Sans';
  @State displayFont: string = 'HarmonyOS Sans';
  @State readyChannels: number = 0;
  @State homeHeight: number = 0;

  aboutToAppear(): void {
    let agreed = false;
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const custom = VideoStore.load(context);
      for (const item of custom) {
        item.custom = true;
      }
      this.videoList = [...custom, ...BUILTIN_VIDEOS];
      // 首次启动展示免责声明，同意后记录，不再弹出
      const options: preferences.Options = { name: DISCLAIMER_PREF };
      const prefs = preferences.getPreferencesSync(context, options);
      const raw: preferences.ValueType = prefs.getSync(KEY_DISCLAIMER, false);
      agreed = raw === true;
      hilog.info(DOMAIN, TAG, 'disclaimer v2 raw=%{public}s agreed=%{public}s', JSON.stringify(raw), String(agreed));
    } catch (e) {
      // 偏好读取失败时按"未同意"处理，弹出示声明
      agreed = false;
      hilog.error(DOMAIN, TAG, 'aboutToAppear failed: %{public}s', (e as BusinessError).message ?? '');
    }
    this.disclaimerAccepted = agreed;
    try {
      this.getUIContext().getFont().registerFont({
        familyName: 'TPTVBrand', familySrc: $rawfile('fonts/Sora-SemiBold.ttf')
      });
      this.brandFont = 'TPTVBrand,HarmonyOS Sans';
    } catch (error) {
      hilog.warn(DOMAIN, TAG, '品牌字体未加载，使用系统字体');
    }
    try {
      this.getUIContext().getFont().registerFont({
        familyName: 'TPTVDisplay', familySrc: $rawfile('fonts/TPTVDisplay.otf')
      });
      this.displayFont = 'TPTVDisplay,HarmonyOS Sans';
    } catch (error) {
      hilog.warn(DOMAIN, TAG, '标题字体未加载，使用系统字体');
    }
    try {
      this.readyChannels = LiveCatalog.loadDisplay(this.getUIContext().getHostContext() as common.UIAbilityContext).length;
    } catch (error) {
      this.readyChannels = 0;
    }
  }

  acceptDisclaimer(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const options: preferences.Options = { name: DISCLAIMER_PREF };
    const prefs = preferences.getPreferencesSync(context, options);
    prefs.putSync(KEY_DISCLAIMER, true);
    prefs.flushSync();
    this.disclaimerAccepted = true;
  }

  exitApp(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    context.terminateSelf();
  }

  /** 保存自定义片源：置顶显示并持久化 */
  saveCustom(): void {
    const title = this.inputTitle.trim();
    const url = this.inputUrl.trim();
    if (url === '') {
      return;
    }
    const item = VideoItem.online(title === '' ? '自定义视频' : title, url, '自定义片源');
    item.custom = true;
    const custom = [item, ...VideoStore.load(this.getUIContext().getHostContext() as common.UIAbilityContext)];
    VideoStore.save(this.getUIContext().getHostContext() as common.UIAbilityContext, custom);
    this.videoList = [...custom.map((v: VideoItem) => {
      v.custom = true;
      return v;
    }), ...BUILTIN_VIDEOS];
    this.inputTitle = '';
    this.inputUrl = '';
    this.showAdd = false;
  }

  /** 删除自定义片源（内置片源不可删） */
  removeCustom(item: VideoItem): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const custom = VideoStore.load(context).filter((v: VideoItem) => v.url !== item.url);
    VideoStore.save(context, custom);
    for (const v of custom) {
      v.custom = true;
    }
    this.videoList = [...custom, ...BUILTIN_VIDEOS];
  }

  @Builder
  private moreMenu() {
    Menu() {
      MenuItem({ content: '播放测试' })
        .onClick(() => {
          this.showAdd = false;
          this.showTests = true;
        })
    }
    .font({ size: 14 })
    .fontColor('#EEEEEE')
    .backgroundColor('#161616')
    .borderRadius(8)
  }

  @Builder
  private testSheet() {
    Column({ space: 16 }) {
      Row() {
        Text('播放测试')
          .fontSize(20)
          .fontColor('#EEEEEE')
          .layoutWeight(1)
        Button({ type: ButtonType.Normal }) {
          SymbolGlyph($r('sys.symbol.plus'))
            .fontSize(20)
            .fontColor(['#68DDD0'])
        }
        .width(44)
        .height(44)
        .backgroundColor(Color.Transparent)
        .accessibilityText(this.showAdd ? '收起添加视频' : '添加视频')
        .onClick(() => {
          this.showAdd = !this.showAdd;
        })
      }
      .width('100%')
      if (this.showAdd) {
        Column({ space: 12 }) {
          TextInput({ text: this.inputTitle, placeholder: '视频名称（选填）' })
            .fontSize(14)
            .fontColor('#EEEEEE')
            .placeholderColor('#777777')
            .backgroundColor('#161616')
            .border({ width: 1, color: '#333333' })
            .borderRadius(8)
            .height(48)
            .onChange((value: string) => {
              this.inputTitle = value;
            })
          TextInput({ text: this.inputUrl, placeholder: '视频地址' })
            .fontSize(14)
            .fontColor('#EEEEEE')
            .placeholderColor('#777777')
            .backgroundColor('#161616')
            .border({ width: 1, color: '#333333' })
            .borderRadius(8)
            .height(48)
            .onChange((value: string) => {
              this.inputUrl = value;
            })
          Button('保存视频', { type: ButtonType.Normal })
            .fontSize(14)
            .fontColor('#000000')
            .backgroundColor('#68DDD0')
            .borderRadius(8)
            .height(44)
            .width('100%')
            .enabled(this.inputUrl.trim() !== '')
            .onClick(() => {
              this.saveCustom();
            })
        }
        .width('100%')
      }
      List({ space: 8 }) {
        ForEach(this.videoList, (item: VideoItem, index: number) => {
          ListItem() {
            Row({ space: 8 }) {
              Button({ type: ButtonType.Normal }) {
                Row({ space: 12 }) {
                  SymbolGlyph($r('sys.symbol.play_fill'))
                    .fontSize(18)
                    .fontColor(['#68DDD0'])
                  Column({ space: 5 }) {
                    Text(item.title)
                      .fontSize(16)
                      .fontColor('#EEEEEE')
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(item.custom ? '自定义视频' : '本地演示 · 离线可用')
                      .fontSize(12)
                      .fontColor('#999999')
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                }
                .width('100%')
              }
              .layoutWeight(1)
              .constraintSize({ minHeight: 72 })
              .padding({ left: 12, right: 4, top: 12, bottom: 12 })
              .backgroundColor(Color.Transparent)
              .onClick(() => {
                this.showTests = false;
                router.pushUrl({ url: 'pages/Player', params: item });
              })
              if (item.custom) {
                Button({ type: ButtonType.Normal }) {
                  SymbolGlyph($r('sys.symbol.trash'))
                    .fontSize(18)
                    .fontColor(['#BBBBBB'])
                }
                .width(44)
                .height(44)
                .padding(0)
                .margin({ right: 4 })
                .backgroundColor(Color.Transparent)
                .accessibilityText(`删除${item.title}`)
                .onClick(() => {
                  this.removeCustom(item);
                })
              }
            }
            .width('100%')
            .borderRadius(8)
            .backgroundColor('#161616')
            .border({ width: 0.5, color: '#303030' })
          }
        }, (item: VideoItem, index: number) => `${index}|${item.rawFile}|${item.url}`)
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 20, right: 20, top: 8, bottom: 24 })
  }

  build() {
    Stack() {
      Column() {
        Row() {
          Text('TPTV')
            .fontFamily(this.brandFont)
            .fontSize(26)
            .fontColor('#E8EBEA')
            .layoutWeight(1)
          Button({ type: ButtonType.Normal }) {
            SymbolGlyph($r('sys.symbol.more'))
              .fontSize(24)
              .fontColor(['#BBBBBB'])
          }
          .width(44)
          .height(44)
          .padding(0)
          .backgroundColor(Color.Transparent)
          .accessibilityText('更多')
          .bindMenu(this.moreMenu())
        }
        .width('100%')
        .height(72)

        Scroll() {
          Column() {
            Image($r('app.media.icon'))
              .width(148)
              .height(148)
              .objectFit(ImageFit.Contain)
              .margin({ bottom: 20 })
            Text('电视直播')
              .fontFamily(this.displayFont)
              .fontSize(32)
              .fontColor('#E8EBEA')
              .margin({ bottom: 12 })
            Text('多源直播 · M3U 订阅 · 节目单')
              .fontFamily('HarmonyOS Sans')
              .fontSize(14)
              .fontColor('#A0A6A4')
              .lineHeight(24)
              .textAlign(TextAlign.Center)
              .width('100%')
            Button({ type: ButtonType.Normal }) {
              Row({ space: 10 }) {
                SymbolGlyph($r('sys.symbol.play_fill'))
                  .fontSize(17)
                  .fontColor(['#080C0B'])
                Text('观看直播')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#080C0B')
              }
            }
            .width(220)
            .height(52)
            .borderRadius(8)
            .backgroundColor('#68DDD0')
            .margin({ top: 28 })
            .onClick(() => {
              router.pushUrl({ url: 'pages/Live' });
            })
            Text(this.readyChannels > 0 ? `内置 ${this.readyChannels} 个频道 · 已就绪` : '内置频道 · 支持自定义订阅')
              .fontSize(12)
              .fontColor('#747D79')
              .textAlign(TextAlign.Center)
              .width('100%')
              .margin({ top: 16 })
          }
          .width('100%')
          .constraintSize({ minHeight: this.homeHeight })
          .justifyContent(FlexAlign.Center)
          .padding({ top: 16, bottom: 24 })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .onAreaChange((_oldArea: Area, newArea: Area) => {
          this.homeHeight = Number(newArea.height);
        })

        Column({ space: 5 }) {
          Text('原生视听，自在入席')
            .fontSize(13)
            .fontColor('#B2B9B5')
          Text('HarmonyOS · AVPlayer / RCP')
            .fontFamily('HarmonyOS Sans')
            .fontSize(11)
            .fontColor('#68716D')
        }
        .width('100%')
        .padding({ top: 16, bottom: 24 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Black)
      .padding({ left: 24, right: 24 })
      .bindSheet($$this.showTests, this.testSheet(), {
        height: '85%',
        backgroundColor: '#0D0D0D',
        showClose: true,
        dragBar: true,
        preferType: SheetType.BOTTOM
      })

      // 首次启动免责声明（同意后持久化记录，不再弹出）
      if (!this.disclaimerAccepted) {
        Column() {
          Column({ space: 12 }) {
            Text('免责声明与使用须知')
              .fontSize(20)
              .fontWeight(FontWeight.Medium)
              .fontColor('#EEEEEE')
              .margin({ top: 20 })

            Scroll() {
              Text('本应用仅供 HarmonyOS 应用开发技术学习研究使用。\n'
                + '1. 本应用不提供、不存储、不制作、不传播任何影视内容，仅演示 AVPlayer / RCP 等开发技术；\n'
                + '2. 内置频道地址均来自公共互联网开源聚合索引（iptv-org、Guovin/iptv-api 等），未验证其授权状态；\n'
                + '3. 严禁用于商业用途或向公众分发，请遵守所在国家/地区法律法规；\n'
                + '4. 如内容侵犯您的权益，请联系仓库维护者，核实后立即移除；\n'
                + '5. 使用本应用产生的一切后果由使用者自行承担。')
                .fontSize(15)
                .fontColor('#CCFFFFFF')
                .lineHeight(24)
            }
            .constraintSize({ minHeight: 120, maxHeight: 260 })
            .padding({ left: 4, right: 4 })

            Row({ space: 12 }) {
              Button('退出应用')
                .fontSize(16)
                .fontColor('#CCCCCC')
                .backgroundColor('#252525')
                .layoutWeight(1)
                .onClick(() => {
                  this.exitApp();
                })
              Button('同意并继续')
                .fontSize(16)
                .fontColor('#000000')
                .backgroundColor('#68DDD0')
                .layoutWeight(2)
                .onClick(() => {
                  this.acceptDisclaimer();
                })
            }
            .width('100%')
            .margin({ top: 6, bottom: 20 })
          }
          .width('92%')
          .padding({ left: 20, right: 20 })
          .borderRadius(8)
          .backgroundColor('#161616')
          .border({ width: 1, color: '#333333' })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor('#D0000000')
      }
    }
    .width('100%')
    .height('100%')
  }
}
