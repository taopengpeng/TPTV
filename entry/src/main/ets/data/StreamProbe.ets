import { rcp } from '@kit.RemoteCommunicationKit';

/**
 * 直播源测活：GET 请求 5 秒超时哨兵 + 连接/传输短超时。
 * 判定"可播放"标准：HTTP 2xx，且内容为 HLS 播放列表（#EXTM3U）或直连 TS 流；
 * 非 2xx（含 403/404）一律视为不可用，保证进入播放列表的源都真正可播。
 * 运行期中途失效由播放页自动切换同频道备用源兜底。
 */
export class StreamProbe {
  private static session?: rcp.Session;

  private static getSession(): rcp.Session {
    if (!StreamProbe.session) {
      const config: rcp.SessionConfiguration = {
        requestConfiguration: {
          transfer: {
            timeout: {
              connectMs: 4000,
              transferMs: 5000
            }
          }
        }
      };
      StreamProbe.session = rcp.createSession(config);
    }
    return StreamProbe.session;
  }

  /** 5 秒超时哨兵：超时返回 null */
  private static timeoutFlag(ms: number): Promise<rcp.Response | null> {
    return new Promise<rcp.Response | null>((resolve) => {
      setTimeout(() => resolve(null), ms);
    });
  }

  static async check(url: string): Promise<boolean> {
    try {
      const resp: rcp.Response | null = await Promise.race([
        StreamProbe.getSession().get(url),
        StreamProbe.timeoutFlag(5000)
      ]);
      if (resp === null) {
        return false;
      }
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        return false;
      }
      if (url.endsWith('.ts')) {
        return true;
      }
      const text: string | null = resp.toString();
      return text !== null && text.includes('#EXTM3U');
    } catch (e) {
      return false;
    }
  }
}
