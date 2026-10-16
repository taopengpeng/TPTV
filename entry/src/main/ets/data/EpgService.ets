import { rcp } from '@kit.RemoteCommunicationKit';
import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ChannelFilter } from '../model/ChannelFilter';

const TAG: string = 'EpgService';
const DOMAIN: number = 0x0000;
const CACHE_TTL_MS: number = 12 * 3600 * 1000;

const EPG_URLS: string[] = [
  'https://live.fanmingming.com/e.xml',
  'https://epg.v1.mk/fy.xml'
];

class EpgProgramme {
  startMs: number = 0;
  stopMs: number = 0;
  title: string = '';
}

/**
 * 播放页展示的当前节目信息
 */
export class EpgNow {
  ok: boolean = false;
  nowTitle: string = '';
  nextTitle: string = '';
}

/**
 * EPG 节目单服务：
 * - 从公共 XMLTV 源下载（多地址兜底），缓存到应用文件目录，12 小时内不重复下载
 * - 正则扫描 XMLTV（不依赖 XML 解析器）：channel/display-name 建立名称索引，
 *   programme 提取 start/stop/title，仅保留当前时刻之后的条目以控制内存
 * - 任何失败（网络不通/解析为空）都优雅降级：界面不显示节目信息
 */
export class EpgService {
  private static loaded: boolean = false;
  private static loading: Promise<boolean> | null = null;
  /** 频道名归一化 key → EPG channel id */
  private static nameToId: Map<string, string> = new Map();
  /** EPG channel id → 节目列表（按开始时间升序） */
  private static programmes: Map<string, EpgProgramme[]> = new Map();

  static isLoaded(): boolean {
    return EpgService.loaded;
  }

  /** 确保索引就绪（重复调用只会加载一次） */
  static ensureLoaded(context: common.UIAbilityContext): Promise<boolean> {
    if (EpgService.loaded) {
      return Promise.resolve(true);
    }
    if (EpgService.loading === null) {
      EpgService.loading = EpgService.load(context).then((ok: boolean) => {
        EpgService.loaded = ok;
        EpgService.loading = null;
        return ok;
      });
    }
    return EpgService.loading;
  }

  /** 查询频道当前/下一个节目（频道名先归一化再匹配） */
  static current(name: string): EpgNow {
    const result = new EpgNow();
    const id = EpgService.nameToId.get(ChannelFilter.normalizeKey(name));
    if (id === undefined) {
      return result;
    }
    const list = EpgService.programmes.get(id);
    if (!list) {
      return result;
    }
    const now = Date.now();
    for (let i = 0; i < list.length; i++) {
      const p = list[i];
      if (p.startMs <= now && now < p.stopMs) {
        result.ok = true;
        result.nowTitle = p.title;
        if (i + 1 < list.length) {
          result.nextTitle = list[i + 1].title;
        }
        break;
      }
    }
    return result;
  }

  private static async load(context: common.UIAbilityContext): Promise<boolean> {
    const path = `${context.filesDir}/epg.xml`;
    let text = '';
    let needDownload = true;
    try {
      const stat = fileIo.statSync(path);
      if (Date.now() - stat.mtime * 1000 < CACHE_TTL_MS && stat.size > 1024) {
        text = EpgService.readText(path);
        needDownload = false;
      }
    } catch (e) {
      needDownload = true;
    }
    if (needDownload) {
      text = await EpgService.download();
      if (text === '') {
        hilog.warn(DOMAIN, TAG, 'epg download failed, epg disabled');
        return false;
      }
      try {
        const file = fileIo.openSync(path, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
        fileIo.writeSync(file.fd, text);
        fileIo.closeSync(file);
      } catch (e) {
        // 缓存写失败不影响本次解析
      }
    }
    EpgService.parse(text);
    hilog.info(DOMAIN, TAG, 'epg loaded: %{public}d channels', EpgService.programmes.size);
    return EpgService.programmes.size > 0;
  }

  private static readText(path: string): string {
    const file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
    const stat = fileIo.statSync(path);
    const buf = new ArrayBuffer(stat.size);
    fileIo.readSync(file.fd, buf);
    fileIo.closeSync(file);
    return EpgService.decode(buf);
  }

  private static decode(buf: ArrayBuffer): string {
    return util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(buf));
  }

  private static async download(): Promise<string> {
    const session = rcp.createSession({
      requestConfiguration: {
        transfer: {
          timeout: {
            connectMs: 8000,
            transferMs: 60000
          }
        }
      }
    });
    try {
      for (const url of EPG_URLS) {
        try {
          const resp: rcp.Response = await session.get(url);
          if (resp.statusCode >= 200 && resp.statusCode < 300) {
            const text: string | null = resp.toString();
            if (text !== null && text.includes('<tv')) {
              return text;
            }
          }
        } catch (e) {
          // 尝试下一个地址
        }
      }
    } finally {
      session.close();
    }
    return '';
  }

  private static decodeEntities(s: string): string {
    return s.replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, "'");
  }

  private static toMs(attr: string): number {
    const m = /(\d{4})(\d{2})(\d{2})(\d{2})?(\d{2})?(\d{2})?/.exec(attr);
    if (!m) {
      return 0;
    }
    return new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]),
      m[4] ? Number(m[4]) : 0, m[5] ? Number(m[5]) : 0, m[6] ? Number(m[6]) : 0).getTime();
  }

  private static parse(text: string): void {
    const now = Date.now();
    const nameToId: Map<string, string> = new Map();
    const programmes: Map<string, EpgProgramme[]> = new Map();

    // 1) 频道表：<channel id="...">...<display-name>名称</display-name>...
    const chRe = /<channel id="([^"]*)"[^>]*>([\s\S]*?)<\/channel>/g;
    let m: RegExpExecArray | null = chRe.exec(text);
    while (m !== null) {
      const id = EpgService.decodeEntities(m[1]);
      const nameRe = /<display-name[^>]*>([^<]*)<\/display-name>/g;
      let nm: RegExpExecArray | null = nameRe.exec(m[2]);
      while (nm !== null) {
        const key = ChannelFilter.normalizeKey(EpgService.decodeEntities(nm[1]));
        if (key !== '' && !nameToId.has(key)) {
          nameToId.set(key, id);
        }
        nm = nameRe.exec(m[2]);
      }
      if (!nameToId.has(ChannelFilter.normalizeKey(EpgService.decodeEntities(id)))) {
        nameToId.set(ChannelFilter.normalizeKey(EpgService.decodeEntities(id)), id);
      }
      m = chRe.exec(text);
    }

    // 2) 节目表：<programme start=".." stop=".." channel=".."><title>..</title></programme>
    const progRe = /<programme ([^>]*)>([\s\S]*?)<\/programme>/g;
    const startRe = /start="([^"]*)"/;
    const stopRe = /stop="([^"]*)"/;
    const chAttrRe = /channel="([^"]*)"/;
    const titleRe = /<title[^>]*>([^<]*)<\/title>/;
    let pm: RegExpExecArray | null = progRe.exec(text);
    while (pm !== null) {
      const attrs = pm[1];
      const sm = startRe.exec(attrs);
      const em = stopRe.exec(attrs);
      const cm = chAttrRe.exec(attrs);
      const tm = titleRe.exec(pm[2]);
      if (sm && em && cm && tm) {
        const p = new EpgProgramme();
        p.startMs = EpgService.toMs(EpgService.decodeEntities(sm[1]));
        p.stopMs = EpgService.toMs(EpgService.decodeEntities(em[1]));
        p.title = EpgService.decodeEntities(tm[1]);
        if (p.stopMs >= now && p.title !== '') {
          const list = programmes.get(cm[1]);
          if (!list) {
            programmes.set(cm[1], [p]);
          } else {
            list.push(p);
          }
        }
      }
      pm = progRe.exec(text);
    }

    // 3) 装配：key（频道名或 id）→ 节目列表
    EpgService.nameToId = nameToId;
    EpgService.programmes = programmes;
  }
}
