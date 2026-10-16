import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { LiveChannel } from '../model/LiveChannel';
import { M3uParser } from '../model/M3uParser';
import { ChannelFilter } from '../model/ChannelFilter';
import { BuiltinChannels } from './BuiltinChannels';

/**
 * 直播片源目录：
 * - live_filtered.m3u：Mac 端预过滤快照（2026-09-16 全量测活 + CCTV 补全：
 *   1762+145 个源 → 320+ 频道），播放列表直接使用，App 内零等待。
 * - live_intl.m3u：国际频道快照（2026-09-16 测活：118 个候选 → 53 个可用频道，
 *   Al Jazeera / DW / France 24 / NHK World / Arirang / Bloomberg / TRT 等）。
 * - live_guovin.m3u / live_vbskycn.m3u / BuiltinChannels：过滤前的完整源，保留备用，
 *   可在直播页手动"重新去重测活"重新过滤，或通过 m3u 订阅刷新。
 */
export class LiveCatalog {
  private static readonly FILTERED_FILE: string = 'live_filtered.m3u';
  private static readonly INTL_FILE: string = 'live_intl.m3u';
  private static readonly RAW_FILES: string[] = ['live_guovin.m3u', 'live_vbskycn.m3u'];

  /** 播放列表：预过滤快照 + 国际频道，同名频道归并为一条（首条为主源，其余挂 alts） */
  static loadDisplay(context: common.UIAbilityContext): LiveChannel[] {
    const all = LiveCatalog.readM3u(context, LiveCatalog.FILTERED_FILE);
    all.push(...LiveCatalog.readM3u(context, LiveCatalog.INTL_FILE));
    if (all.length === 0) {
      all.push(...BuiltinChannels.all());
    }
    return LiveCatalog.onePerChannel(LiveCatalog.dedupe(all));
  }

  /** 过滤前的完整源（原始快照 + 人工验证频道），保留备用 */
  static loadFull(context: common.UIAbilityContext): LiveChannel[] {
    const all: LiveChannel[] = BuiltinChannels.all();
    for (const file of LiveCatalog.RAW_FILES) {
      all.push(...LiveCatalog.readM3u(context, file));
    }
    return LiveCatalog.dedupe(all);
  }

  /** 同名频道归并为一条：首条为主源展示，其余源挂 alts 供播放页切换 */
  private static onePerChannel(list: LiveChannel[]): LiveChannel[] {
    const order: string[] = [];
    const map = new Map<string, LiveChannel>();
    for (const ch of list) {
      const key = ChannelFilter.normalizeKey(ch.name);
      const primary = map.get(key);
      if (!primary) {
        ch.alts = [];
        map.set(key, ch);
        order.push(key);
      } else {
        primary.alts.push(ch);
      }
    }
    const result: LiveChannel[] = [];
    for (const k of order) {
      const ch = map.get(k);
      if (ch) {
        result.push(ch);
      }
    }
    return result;
  }

  private static readM3u(context: common.UIAbilityContext, file: string): LiveChannel[] {
    try {
      const bytes: Uint8Array = context.resourceManager.getRawFileContentSync(file);
      const text: string = util.TextDecoder.create('utf-8').decodeToString(bytes);
      return M3uParser.parse(text);
    } catch (e) {
      return [];
    }
  }

  /** 相同地址只保留一条（多份源快照间大量重叠） */
  private static dedupe(list: LiveChannel[]): LiveChannel[] {
    const seen: Set<string> = new Set<string>();
    const result: LiveChannel[] = [];
    for (const ch of list) {
      if (ch.url === '' || seen.has(ch.url)) {
        continue;
      }
      seen.add(ch.url);
      result.push(ch);
    }
    return result;
  }
}
