import { LiveChannel } from './LiveChannel';

/**
 * 按归一化名称聚合的频道组（同一频道的多个来源，如 "CCTV-1 (1080p)" / "CCTV1" / "CCTV-1综合"）
 */
export class ChannelGroup {
  key: string;
  display: string;
  group: string;
  candidates: LiveChannel[];

  constructor(key: string, display: string, group: string) {
    this.key = key;
    this.display = display;
    this.group = group;
    this.candidates = [];
  }
}

/**
 * 订阅源过滤流水线：
 * 1. 名称归一化去重（去清晰度/括号修饰，同名归为一组，重复地址只留一条）
 * 2. 组内按原顺序探测可播放性，凑满 KEEP_PER_CHANNEL 个可用源即停（单组最多试 MAX_TRIED_PER_GROUP 个）
 * 3. 每组保留的可用源直接追加到播放列表（同名互为备用，播放失败自动切换）
 */
export class ChannelFilter {
  static readonly KEEP_PER_CHANNEL: number = 3;
  static readonly MAX_TRIED_PER_GROUP: number = 8;
  static readonly CONCURRENCY: number = 12;

  static normalizeKey(name: string): string {
    const key = name.toLowerCase()
      .replace(/（[^）]*）|\([^)]*\)|【[^】]*】|\[[^\]]*\]/g, '')
      .replace(/1080p|720p|480p|4k|8k|fhd|uhd|hdr|超高清|超清|高清|蓝光|标清/g, '')
      .replace(/[^a-z0-9\u4e00-\u9fa5]+/g, '');
    return key === '' ? name : key;
  }

  static group(channels: LiveChannel[]): ChannelGroup[] {
    const order: string[] = [];
    const map = new Map<string, ChannelGroup>();
    const seenUrls = new Set<string>();
    for (const ch of channels) {
      if (ch.url === '' || seenUrls.has(ch.url)) {
        continue;
      }
      seenUrls.add(ch.url);
      const key = ChannelFilter.normalizeKey(ch.name);
      if (/^\d+$/.test(key)) {
        continue; // 过滤日期/时间戳等被误标为频道的垃圾条目
      }
      let g = map.get(key);
      if (!g) {
        g = new ChannelGroup(key, ch.name, ch.group);
        map.set(key, g);
        order.push(key);
      }
      g.candidates.push(ch);
    }
    const groups: ChannelGroup[] = [];
    for (const k of order) {
      const g = map.get(k);
      if (g) {
        groups.push(g);
      }
    }
    return groups;
  }

  /**
   * 组级并发（CONCURRENCY 路）+ 组内顺序探测、凑满即停。
   * 每完成一组通过 onGroupReady 上报该组保留的可用源，onProgress 上报整体进度。
   */
  static async filterPlayable(groups: ChannelGroup[], probe: (url: string) => Promise<boolean>,
    onGroupReady: (kept: LiveChannel[]) => void,
    onProgress: (groupsDone: number, groupsTotal: number, probed: number) => void): Promise<void> {
    const total = groups.length;
    let next = 0;
    let done = 0;
    let probed = 0;

    const worker = async (): Promise<void> => {
      while (next < total) {
        const g = groups[next];
        next++;
        const kept: LiveChannel[] = [];
        let tried = 0;
        for (const c of g.candidates) {
          tried++;
          probed++;
          let ok = false;
          try {
            ok = await probe(c.url);
          } catch (err) {
            ok = false;
          }
          if (ok) {
            kept.push(c);
            if (kept.length >= ChannelFilter.KEEP_PER_CHANNEL) {
              break;
            }
          }
          if (tried >= ChannelFilter.MAX_TRIED_PER_GROUP) {
            break;
          }
        }
        if (kept.length > 0) {
          onGroupReady(kept);
        }
        done++;
        onProgress(done, total, probed);
      }
    };

    const workers: Promise<void>[] = [];
    const parallel = Math.min(ChannelFilter.CONCURRENCY, total);
    for (let i = 0; i < parallel; i++) {
      workers.push(worker());
    }
    await Promise.all(workers);
  }
}
