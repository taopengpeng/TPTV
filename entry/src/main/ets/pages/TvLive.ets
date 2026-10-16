import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { LiveChannel } from '../model/LiveChannel';
import { LiveStore } from '../model/LiveStore';
import { VideoItem } from '../model/VideoItem';
import { LiveCatalog } from '../data/LiveCatalog';

/**
 * TV 端选台首页：开机自动进入第一个频道直接播放（pushUrl，遥控器“返回”
 * 会回到本页的频道宫格，用焦点移动 + OK 键选台）。手机端不走本页。
 * 数据与手机端一致：使用预过滤快照（LiveCatalog）。
 */
@Entry
@Component
struct TvLive {
  @State channels: LiveChannel[] = [];
  @State focusedIndex: number = 0;
  private hasAutoPlayed: boolean = false;

  aboutToAppear(): void {
    if (LiveStore.channels.length === 0) {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      LiveStore.channels = LiveCatalog.loadDisplay(context);
      LiveStore.fullChannels = LiveCatalog.loadFull(context);
    }
    this.channels = LiveStore.channels;
  }

  onPageShow(): void {
    // 首次显示即开播；从播放页返回时不再自动跳转，停留在本选台列表
    if (this.hasAutoPlayed || this.channels.length === 0) {
      return;
    }
    this.hasAutoPlayed = true;
    this.playChannel(Math.min(LiveStore.currentIndex, this.channels.length - 1));
  }

  playChannel(index: number): void {
    const ch = this.channels[index];
    if (!ch) {
      return;
    }
    LiveStore.currentIndex = index;
    router.pushUrl({ url: 'pages/Player', params: VideoItem.live(ch.name, ch.url, ch.group) });
  }

  build() {
    Column() {
      Text('电视直播')
        .fontSize(40)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F0FFFFFF')
        .margin({ top: 36, bottom: 10 })

      Text('OK 键选台 · 播放中按上/下键换台 · 返回键回到此列表')
        .fontSize(16)
        .fontColor('#88FFFFFF')
        .margin({ bottom: 24 })

      Grid() {
        ForEach(this.channels, (ch: LiveChannel, index: number) => {
          GridItem() {
            Column({ space: 8 }) {
              if (ch.logo !== '') {
                Image(ch.logo)
                  .width(84)
                  .height(44)
                  .objectFit(ImageFit.Contain)
                  .alt($r('app.media.icon'))
              }
              Text(ch.name)
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .fontColor('#F0FFFFFF')
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .textAlign(TextAlign.Center)
            }
            .width('100%')
            .height(120)
            .justifyContent(FlexAlign.Center)
            .padding({ left: 12, right: 12 })
            .borderRadius(14)
            .backgroundColor(this.focusedIndex === index ? '#2A2A4E' : '#1A1A2E')
            .border({
              width: 3,
              color: this.focusedIndex === index ? '#59B6FF' : Color.Transparent
            })
            .scale(this.focusedIndex === index ? { x: 1.04, y: 1.04 } : { x: 1, y: 1 })
            .focusable(true)
            .focusOnTouch(true)
            .defaultFocus(index === 0)
            .onFocus(() => {
              this.focusedIndex = index;
            })
            .onClick(() => {
              this.playChannel(index);
            })
          }
        }, (ch: LiveChannel, index: number) => `${index}-${ch.url}`)
      }
      .columnsTemplate('1fr 1fr 1fr 1fr')
      .rowsGap(14)
      .columnsGap(14)
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 48, right: 48, bottom: 32 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0B0B15')
  }
}
