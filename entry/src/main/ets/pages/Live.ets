import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { fileIo } from '@kit.CoreFileKit';
import { LiveChannel } from '../model/LiveChannel';
import { LiveStore } from '../model/LiveStore';
import { M3uParser } from '../model/M3uParser';
import { ChannelFilter } from '../model/ChannelFilter';
import { VideoItem } from '../model/VideoItem';
import { LiveCatalog } from '../data/LiveCatalog';
import { StreamProbe } from '../data/StreamProbe';
import { HistoryItem, FavoriteStore } from '../data/FavoriteStore';
import { EpgService } from '../data/EpgService';
import { MobileApi } from '../net/MobileApi';
import { NetCallBack } from '../net/NetCallBack';

const PREF_NAME: string = 'liveSettings';
const KEY_SUB_URL: string = 'sub_url';

/**
 * 订阅刷新回调（ArkTS 下用类代替对象字面量实现接口）
 */
class RefreshChannelsCallback implements NetCallBack<string> {
  private readonly onOk: (text: string, errorMsg: string) => void;
  private readonly onErr: (msg: string) => void;

  constructor(onOk: (text: string, errorMsg: string) => void, onErr: (msg: string) => void) {
    this.onOk = onOk;
    this.onErr = onErr;
  }

  onSuccess(text: string, errorMsg: string): void {
    this.onOk(text, errorMsg);
  }

  onFail(msg: string): void {
    this.onErr(msg);
  }
}

@Observed
class ChannelRow {
  key: string;
  channel: LiveChannel;
  favorite: boolean = false;
  showAll: boolean = false;
  verified: boolean = false;
  program: string = '';
  programUpdatedAt: number = 0;

  constructor(key: string, channel: LiveChannel) {
    this.key = key;
    this.channel = channel;
  }
}

class ChannelDataSource implements IDataSource {
  private rows: ChannelRow[] = [];
  private listeners: DataChangeListener[] = [];
  private activeKeys: Set<string> = new Set<string>();
  private readonly programOf: (channel: LiveChannel) => string;

  constructor(programOf: (channel: LiveChannel) => string) {
    this.programOf = programOf;
  }

  totalCount(): number {
    return this.rows.length;
  }

  getData(index: number): ChannelRow {
    return this.rows[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (!this.listeners.includes(listener)) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    this.listeners = this.listeners.filter((current: DataChangeListener) => current !== listener);
  }

  replace(channels: LiveChannel[], favorites: string[], showAll: boolean, verified: Set<string>): void {
    const previous: Map<string, ChannelRow> = new Map<string, ChannelRow>();
    for (const row of this.rows) {
      previous.set(row.key, row);
    }
    const occurrences: Map<string, number> = new Map<string, number>();
    const favoriteKeys: Set<string> = new Set<string>(favorites);
    const next: ChannelRow[] = channels.map((channel: LiveChannel) => {
      const identity = JSON.stringify([channel.name, channel.url, channel.group]);
      const occurrence = occurrences.get(identity) ?? 0;
      occurrences.set(identity, occurrence + 1);
      const key = `${identity}#${occurrence}`;
      const row = previous.get(key) ?? new ChannelRow(key, channel);
      if (row.channel !== channel) {
        row.channel = channel;
      }
      row.favorite = favoriteKeys.has(ChannelFilter.normalizeKey(channel.name));
      row.showAll = showAll;
      row.verified = verified.has(channel.url);
      return row;
    });
    const oldCount = this.rows.length;
    const appendOnly = next.length >= oldCount && this.rows.every((row: ChannelRow, index: number) =>
      row.key === next[index].key);
    this.rows = next;
    for (const key of this.activeKeys) {
      if (!next.some((row: ChannelRow) => row.key === key)) {
        this.activeKeys.delete(key);
      }
    }
    for (const listener of this.listeners) {
      if (appendOnly) {
        for (let index = oldCount; index < next.length; index++) {
          listener.onDataAdd(index);
        }
      } else {
        listener.onDataReloaded();
      }
    }
  }

  channels(): LiveChannel[] {
    return this.rows.map((row: ChannelRow) => row.channel);
  }

  indexOf(key: string): number {
    return this.rows.findIndex((row: ChannelRow) => row.key === key);
  }

  activate(row: ChannelRow): void {
    this.activeKeys.add(row.key);
    this.updateProgram(row);
  }

  deactivate(row: ChannelRow): void {
    this.activeKeys.delete(row.key);
  }

  refreshPrograms(invalidate: boolean = false): void {
    for (const row of this.rows) {
      if (invalidate) {
        row.programUpdatedAt = 0;
      }
      if (this.activeKeys.has(row.key)) {
        this.updateProgram(row);
      }
    }
  }

  private updateProgram(row: ChannelRow): void {
    const now = Date.now();
    if (now - row.programUpdatedAt >= 60000) {
      row.program = this.programOf(row.channel);
      row.programUpdatedAt = now;
    }
  }
}

@Component
struct ChannelListRow {
  @ObjectLink row: ChannelRow;
  @State pressed: boolean = false;
  onPlay: (key: string) => void = () => {};
  onFavorite: (channel: LiveChannel) => void = () => {};
  onActivate: (row: ChannelRow) => void = () => {};
  onDeactivate: (row: ChannelRow) => void = () => {};

  aboutToAppear(): void {
    this.onActivate(this.row);
  }

  aboutToDisappear(): void {
    this.onDeactivate(this.row);
  }

  build() {
    Row({ space: 4 }) {
      Button({ type: ButtonType.Normal }) {
        Row({ space: 12 }) {
          if (this.row.channel.logo !== '') {
            Image(this.row.channel.logo)
              .width(48)
              .height(34)
              .objectFit(ImageFit.Contain)
              .borderRadius(6)
              .alt($r('app.media.icon'))
          }
          Column({ space: 5 }) {
            Row({ space: 8 }) {
              Text(this.row.channel.name)
                .fontSize(16)
                .fontColor('#E8EBEA')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
              if (this.row.showAll) {
                Text(this.row.verified ? '已验证' : '未验证')
                  .fontSize(11)
                  .fontColor(this.row.verified ? '#68DDD0' : '#999999')
                  .padding({ left: 5, right: 5, top: 2, bottom: 2 })
                  .borderRadius(4)
                  .border({ width: 0.5, color: '#3B4340' })
              } else if (this.row.channel.alts.length > 0) {
                Text(`${this.row.channel.alts.length + 1}线路`)
                  .fontSize(11)
                  .fontColor('#68DDD0')
                  .padding({ left: 5, right: 5, top: 2, bottom: 2 })
                  .borderRadius(4)
                  .border({ width: 0.5, color: '#3B4340' })
              }
            }
            .width('100%')
            if (this.row.program !== '') {
              Text(this.row.program)
                .fontSize(12)
                .fontColor('#959D99')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')
            }
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
      }
      .layoutWeight(1)
      .constraintSize({ minHeight: 72 })
      .padding({ left: 12, right: 4, top: 12, bottom: 12 })
      .borderRadius(8)
      .backgroundColor(this.pressed ? '#18FFFFFF' : Color.Transparent)
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.pressed = true;
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.pressed = false;
        }
      })
      .accessibilityText(`播放${this.row.channel.name}`)
      .onClick(() => {
        this.onPlay(this.row.key);
      })
      Button({ type: ButtonType.Normal }) {
        SymbolGlyph(this.row.favorite ? $r('sys.symbol.star_fill') : $r('sys.symbol.star'))
          .fontSize(21)
          .fontColor([this.row.favorite ? '#68DDD0' : '#8B9590'])
      }
      .width(44)
      .height(44)
      .padding(0)
      .margin({ right: 4 })
      .backgroundColor(Color.Transparent)
      .accessibilityText(this.row.favorite ? `取消收藏${this.row.channel.name}` : `收藏${this.row.channel.name}`)
      .onClick(() => {
        this.onFavorite(this.row.channel);
      })
    }
    .width('100%')
    .borderRadius(8)
    .linearGradient({ angle: 180, colors: [['#202422', 0], ['#171A18', 0.4], ['#101311', 1]] })
    .border({ width: { top: 0.8, right: 0.5, bottom: 0.5, left: 0.5 }, color: '#37403B' })
    .shadow({ radius: 3, color: '#80000000', offsetX: 0, offsetY: 2 })
  }
}

@Entry
@Component
struct Live {
  @State @Watch('syncChannels') channels: LiveChannel[] = [];
  @State @Watch('syncChannels') keyword: string = '';
  @State @Watch('syncChannels') category: string = '全部';
  @State categories: string[] = ['全部'];
  @State @Watch('syncChannels') showAll: boolean = false;
  @State @Watch('syncChannels') verifiedUrls: Set<string> = new Set<string>();
  @State @Watch('syncChannels') favKeys: string[] = [];
  @State @Watch('refreshPrograms') epgTick: number = 0;
  @State probing: boolean = false;
  @State subUrl: string = '';
  @State showEditor: boolean = false;
  @State inputText: string = '';
  @State statusText: string = '';
  private channelSource: ChannelDataSource = new ChannelDataSource((channel: LiveChannel) => this.epgLineOf(channel));
  private programTimer: number = -1;

  private syncChannels(): void {
    this.channelSource.replace(this.visibleChannels(), this.favKeys, this.showAll, this.verifiedUrls);
  }

  private refreshPrograms(): void {
    this.channelSource.refreshPrograms(true);
  }

  onPageShow(): void {
    this.favKeys = FavoriteStore.favKeys(this.getUIContext().getHostContext() as common.UIAbilityContext);
    this.syncChannels();
    this.refreshPrograms();
    this.stopProgramTimer();
    this.programTimer = setInterval(() => this.channelSource.refreshPrograms(), 60000);
  }

  onPageHide(): void {
    this.stopProgramTimer();
  }

  aboutToDisappear(): void {
    this.stopProgramTimer();
  }

  private stopProgramTimer(): void {
    if (this.programTimer !== -1) {
      clearInterval(this.programTimer);
      this.programTimer = -1;
    }
  }

  aboutToAppear(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    // 播放列表直接使用 Mac 端预过滤快照（已去重 + 测活），启动零等待；
    // 过滤前的完整源保留在 LiveStore.fullChannels，可手动"重新去重测活"或订阅刷新。
    const display = LiveCatalog.loadDisplay(context);
    this.channels = display;
    LiveStore.channels = display;
    LiveStore.fullChannels = LiveCatalog.loadFull(context);
    // 已验证地址集合 = 预过滤快照中的全部源（主源 + 备源），用于在"全部源"视图标注
    const verified: Set<string> = new Set<string>();
    for (const ch of display) {
      verified.add(ch.url);
      for (const alt of ch.alts) {
        verified.add(alt.url);
      }
    }
    this.verifiedUrls = verified;
    this.favKeys = FavoriteStore.favKeys(context);
    this.categories = this.buildCategories(display);
    this.statusText = `已加载 ${display.length} 个频道（快照预过滤，每频道一条，备用源在播放页切换）`;
    const options: preferences.Options = { name: PREF_NAME };
    const prefs = preferences.getPreferencesSync(context, options);
    const saved: preferences.ValueType = prefs.getSync(KEY_SUB_URL, '');
    if (typeof saved === 'string' && saved !== '') {
      this.subUrl = saved;
    }
    // EPG 节目单后台加载（拉取/解析失败自动隐藏，不影响列表）
    EpgService.ensureLoaded(context).then((ok: boolean) => {
      if (ok) {
        this.epgTick++;
        this.statusText = `已加载 ${display.length} 个频道（含节目单）`;
      }
    });
    this.syncChannels();
  }

  /** 列表数据源：过滤后的可用频道 或 过滤前的全部源 */
  private baseChannels(): LiveChannel[] {
    return this.showAll ? LiveStore.fullChannels : this.channels;
  }

  private toggleShowAll(showAll: boolean): void {
    if (this.showAll === showAll) {
      return;
    }
    this.showAll = showAll;
    this.category = '全部';
    this.categories = this.buildCategories(this.baseChannels());
  }

  /** 频道归类：央视 / 卫视 / 港澳台 / 国际 / 专题 / 地方 */
  private bucketOf(ch: LiveChannel): string {
    const t = `${ch.group} ${ch.name}`;
    if (t.includes('央视') || /cctv|cgtn/i.test(t)) {
      return '央视';
    }
    if (t.includes('卫视')) {
      return '卫视';
    }
    if (t.includes('🌍') || t.includes('国际')) {
      return '国际';
    }
    if (t.includes('港') || t.includes('澳') || t.includes('台湾') || t.includes('TVB') || /[{(]台[)}]|·台|台·/.test(t)) {
      return '港澳台';
    }
    if (/电影|纪录|体育|音乐|儿童|剧场|春晚|教育|购物|赛事/.test(t)) {
      return '专题';
    }
    return '地方';
  }

  private buildCategories(list: LiveChannel[]): string[] {
    const buckets: string[] = [];
    for (const ch of list) {
      const b = this.bucketOf(ch);
      if (!buckets.includes(b)) {
        buckets.push(b);
      }
    }
    return ['全部', '⭐ 收藏', ...buckets, '🕘 历史'];
  }

  private isFav(ch: LiveChannel): boolean {
    return this.favKeys.indexOf(ChannelFilter.normalizeKey(ch.name)) >= 0;
  }

  private toggleFav(ch: LiveChannel): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    FavoriteStore.toggle(context, ChannelFilter.normalizeKey(ch.name));
    this.favKeys = FavoriteStore.favKeys(context);
  }

  private epgLineOf(ch: LiveChannel): string {
    const epg = EpgService.current(ch.name);
    if (!epg || !epg.ok || epg.nowTitle === '') {
      return '';
    }
    return epg.nextTitle !== '' ? `正在播：${epg.nowTitle} · 接下来：${epg.nextTitle}` : `正在播：${epg.nowTitle}`;
  }

  /** 按分类与关键词过滤（匹配频道名或分组，不区分大小写） */
  private visibleChannels(): LiveChannel[] {
    const kw = this.keyword.trim().toLowerCase();
    if (this.category === '⭐ 收藏') {
      return this.channels.filter((ch: LiveChannel) =>
        this.favKeys.indexOf(ChannelFilter.normalizeKey(ch.name)) >= 0);
    }
    if (this.category === '🕘 历史') {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      return FavoriteStore.history(context).map((h: HistoryItem) => new LiveChannel(h.name, h.url, h.group));
    }
    return this.baseChannels().filter((ch: LiveChannel) => {
      if (this.category !== '全部' && this.bucketOf(ch) !== this.category) {
        return false;
      }
      if (kw === '') {
        return true;
      }
      return ch.name.toLowerCase().includes(kw) || ch.group.toLowerCase().includes(kw);
    });
  }

  refresh(): void {
    if (this.subUrl === '') {
      this.statusText = '未配置订阅地址，当前显示内置频道';
      return;
    }
    this.statusText = '正在从订阅刷新频道…';
    MobileApi.getInstance().fetchText(this.subUrl).enqueue(new RefreshChannelsCallback(
      (text: string, errorMsg: string) => {
        const full: LiveChannel[] = M3uParser.parse(text);
        if (full.length === 0) {
          this.statusText = '订阅内容为空，保留当前频道';
          return;
        }
        this.persistRawSources(text);
        LiveStore.fullChannels = full;
        this.runFilter();
      },
      (msg: string) => {
        this.statusText = `刷新失败：${msg}，保留当前频道`;
      }
    ));
  }

  /**
   * 去重测活流水线：完整源 → 名称归一化分组（同名归并、重复地址去重）→
   * 组内顺序探测、凑满即停（每频道最多保留 3 个可用源）→ 结果即播放列表。
   * 过滤前的完整源始终保留在 LiveStore.fullChannels（订阅文本另存应用文件目录）。
   */
  async runFilter(): Promise<void> {
    if (this.probing) {
      return;
    }
    this.probing = true;
    const full = LiveStore.fullChannels;
    const groups = ChannelFilter.group(full);
    this.channels = [];
    LiveStore.channels = [];
    this.statusText = `共 ${full.length} 个源、${groups.length} 个频道，开始去重测活…`;
    await ChannelFilter.filterPlayable(groups,
      (url: string): Promise<boolean> => StreamProbe.check(url),
      (kept: LiveChannel[]) => {
        // 每频道只显示一条：首条为主源，其余作为备用源挂在 alts
        const primary = new LiveChannel(kept[0].name, kept[0].url, kept[0].group);
        primary.alts = kept.slice(1);
        this.channels = this.channels.concat(primary);
        LiveStore.channels = this.channels;
      },
      (groupsDone: number, groupsTotal: number, probed: number) => {
        this.statusText = `测活中：频道 ${groupsDone}/${groupsTotal}，已请求 ${probed} 个源，已就绪 ${this.channels.length} 个`;
      });
    this.categories = this.buildCategories(this.channels);
    this.statusText = `过滤完成：${full.length} 个源 → ${this.channels.length} 个可用频道` +
      `（每频道显示一条，备用源在播放页"切源"切换，失效自动兜底）`;
    this.probing = false;
  }

  /** 过滤前的订阅原文写入应用文件目录保留，便于排查与重新过滤 */
  private persistRawSources(text: string): void {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const path = `${context.filesDir}/live_sources_full.m3u`;
      const file = fileIo.openSync(path, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, text);
      fileIo.closeSync(file);
    } catch (err) {
      // 落盘失败不影响过滤流程
    }
  }

  saveSubscription(): void {
    const url = this.inputText.trim();
    if (url === '') {
      return;
    }
    this.subUrl = url;
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const options: preferences.Options = { name: PREF_NAME };
    const prefs = preferences.getPreferencesSync(context, options);
    prefs.putSync(KEY_SUB_URL, url);
    prefs.flushSync();
    this.showEditor = false;
    this.refresh();
  }

  openChannel(index: number): void {
    const list = this.channelSource.channels();
    const ch = list[index];
    if (!ch) {
      return;
    }
    LiveStore.channels = list;
    LiveStore.currentIndex = index;
    router.pushUrl({ url: 'pages/Player', params: VideoItem.live(ch.name, ch.url, ch.group) });
  }

  @Builder
  private channelModeMenu() {
    Menu() {
      MenuItem({ content: '可用频道' })
        .selected(!this.showAll)
        .selectIcon(true)
        .onClick(() => {
          this.toggleShowAll(false);
        })
      MenuItem({ content: '全部频道源（含未验证）' })
        .selected(this.showAll)
        .selectIcon(true)
        .onClick(() => {
          this.toggleShowAll(true);
        })
    }
    .font({ size: 14 })
    .fontColor('#F0FFFFFF')
    .backgroundColor('#111111')
    .borderRadius(8)
  }

  @Builder
  private subscriptionEditor() {
    Column({ space: 16 }) {
      Text('频道源设置')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor('#F0FFFFFF')
        .width('100%')
      Text(this.subUrl === '' ? '已保存配置：内置频道' : '已保存配置：自定义订阅')
        .fontSize(13)
        .fontColor('#999999')
        .width('100%')
      Column({ space: 8 }) {
        Text('频道列表地址（M3U）')
          .fontSize(14)
          .fontColor('#CCCCCC')
          .width('100%')
        TextInput({ text: this.inputText, placeholder: 'https://…/channels.m3u' })
          .fontSize(14)
          .fontColor('#FFFFFF')
          .placeholderColor('#777777')
          .backgroundColor(Color.Transparent)
          .border({ width: 1, color: '#333333' })
          .borderRadius(8)
          .height(48)
          .width('100%')
          .onChange((value: string) => {
            this.inputText = value;
          })
      }
      .width('100%')
      if (this.subUrl !== '') {
        Button({ type: ButtonType.Normal }) {
          Row({ space: 8 }) {
            SymbolGlyph($r('sys.symbol.arrow_clockwise'))
              .fontSize(16)
              .fontColor(['#68DDD0'])
            Text('更新已保存订阅')
              .fontSize(14)
              .fontColor('#68DDD0')
          }
        }
        .height(44)
        .backgroundColor(Color.Transparent)
        .enabled(!this.probing)
        .onClick(() => {
          this.refresh();
        })
      }
      Row({ space: 12 }) {
        Button('取消', { type: ButtonType.Normal })
          .height(44)
          .fontSize(14)
          .fontColor('#CCCCCC')
          .backgroundColor(Color.Transparent)
          .border({ width: 1, color: '#333333' })
          .borderRadius(8)
          .layoutWeight(1)
          .onClick(() => {
            this.showEditor = false;
          })
        Button('保存并更新频道', { type: ButtonType.Normal })
          .height(44)
          .fontSize(14)
          .fontColor('#000000')
          .backgroundColor('#68DDD0')
          .borderRadius(8)
          .layoutWeight(2)
          .enabled(this.inputText.trim() !== '' && !this.probing)
          .onClick(() => {
            this.saveSubscription();
          })
      }
      .width('100%')
      if (this.statusText !== '') {
        Text(this.statusText)
          .fontSize(12)
          .fontColor('#999999')
          .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 20, right: 20, top: 12, bottom: 24 })
  }

  build() {
    Column() {
      Row({ space: 12 }) {
        Text('电视直播')
          .fontSize(24)
          .fontWeight(FontWeight.Medium)
          .fontColor('#F0FFFFFF')
          .layoutWeight(1)

        Button({ type: ButtonType.Normal }) {
          Row({ space: 6 }) {
            Text('频道源')
              .fontSize(14)
              .fontColor('#CCCCCC')
            SymbolGlyph($r('sys.symbol.chevron_down'))
              .fontSize(12)
              .fontColor(['#999999'])
          }
        }
          .height(44)
          .padding({ left: 8, right: 8 })
          .backgroundColor(Color.Transparent)
          .accessibilityText('打开频道源设置')
          .onClick(() => {
            this.inputText = this.subUrl;
            this.showEditor = true;
          })
      }
      .width('100%')
      .margin({ top: 8, bottom: 12 })

      if (this.category !== '⭐ 收藏' && this.category !== '🕘 历史') {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.magnifyingglass'))
            .fontSize(18)
            .fontColor(['#999999'])
          TextInput({ text: this.keyword, placeholder: '搜索频道名或分组' })
            .fontSize(15)
            .fontColor('#FFFFFF')
            .placeholderColor('#777777')
            .backgroundColor(Color.Transparent)
            .cancelButton({ style: CancelButtonStyle.INPUT, icon: { size: 18, color: '#999999' } })
            .height(44)
            .layoutWeight(1)
            .onChange((value: string) => {
              this.keyword = value;
            })
        }
        .width('100%')
        .padding({ left: 12, right: 4 })
        .border({ width: 1, color: '#292929' })
        .borderRadius(8)
        .margin({ bottom: 8 })
      }

      Row({ space: 8 }) {
        Button({ type: ButtonType.Normal }) {
          Row({ space: 6 }) {
            Text(this.showAll ? `全部源 ${LiveStore.fullChannels.length}` : `可用频道 ${this.channels.length}`)
              .fontSize(14)
              .fontColor('#CCCCCC')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
            SymbolGlyph($r('sys.symbol.chevron_down'))
              .fontSize(12)
              .fontColor(['#999999'])
          }
          .width('100%')
        }
          .layoutWeight(1)
          .height(44)
          .padding(0)
          .backgroundColor(Color.Transparent)
          .accessibilityText('选择可用频道或全部频道源')
          .bindMenu(this.channelModeMenu())
        Button({ type: ButtonType.Normal }) {
          Row({ space: 6 }) {
            SymbolGlyph($r('sys.symbol.checkmark_circle'))
              .fontSize(16)
              .fontColor(['#68DDD0'])
            Text(this.probing ? '检测中' : '检测频道')
              .fontSize(14)
              .fontColor('#68DDD0')
          }
        }
          .height(44)
          .padding({ left: 8, right: 0 })
          .backgroundColor(Color.Transparent)
          .enabled(!this.probing)
          .onClick(() => {
            this.runFilter();
          })
      }
      .width('100%')

      if (this.probing || this.statusText.includes('失败') || this.statusText.includes('订阅内容为空') ||
        this.statusText.includes('正在从订阅')) {
        Text(this.statusText)
          .fontSize(12)
          .fontColor(this.statusText.includes('失败') || this.statusText.includes('订阅内容为空') ?
            '#F2B36D' : '#999999')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ bottom: 8 })
      }

      Scroll() {
        Row({ space: 20 }) {
          ForEach(this.categories, (c: string) => {
            Button({ type: ButtonType.Normal }) {
              Row({ space: 6 }) {
                if (c === '⭐ 收藏' || c === '🕘 历史') {
                  SymbolGlyph(c === '⭐ 收藏' ? $r('sys.symbol.star') : $r('sys.symbol.clock'))
                    .fontSize(14)
                    .fontColor([this.category === c ? '#68DDD0' : '#999999'])
                }
                Text(c === '⭐ 收藏' ? '收藏' : (c === '🕘 历史' ? '历史' : c))
                  .fontSize(15)
                  .fontColor(this.category === c ? '#68DDD0' : '#999999')
              }
            }
              .height(44)
              .padding({ left: 0, right: 0, top: 0, bottom: 2 })
              .borderRadius(0)
              .backgroundColor(Color.Transparent)
              .border({ width: { bottom: 2 }, color: this.category === c ? '#68DDD0' : Color.Transparent })
              .onClick(() => {
                this.category = c;
              })
          }, (c: string) => c)
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')

      List({ space: 8 }) {
        LazyForEach(this.channelSource, (row: ChannelRow) => {
          ListItem() {
            ChannelListRow({
              row: row,
              onPlay: (key: string) => this.openChannel(this.channelSource.indexOf(key)),
              onFavorite: (channel: LiveChannel) => this.toggleFav(channel),
              onActivate: (item: ChannelRow) => this.channelSource.activate(item),
              onDeactivate: (item: ChannelRow) => this.channelSource.deactivate(item)
            })
          }
        }, (row: ChannelRow) => row.key)
      }
      .width('100%')
      .layoutWeight(1)
      .cachedCount(6)
      .scrollBar(BarState.Off)
      .padding({ top: 6, bottom: 20 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
    .padding({ left: 16, right: 16 })
    .bindSheet($$this.showEditor, this.subscriptionEditor(), {
      height: SheetSize.FIT_CONTENT,
      backgroundColor: '#000000',
      showClose: true,
      dragBar: true,
      preferType: SheetType.BOTTOM
    })
  }
}
