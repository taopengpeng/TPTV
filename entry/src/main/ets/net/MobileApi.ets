import { rcp } from '@kit.RemoteCommunicationKit';
import { BaseBean } from '../model/BaseBean';
import { JokeBean } from '../model/JokeBean';
import { UserInfo } from '../model/UserInfo';
import { MobileApiUrl } from './MobileApiUrl';
import { NetError } from './NetCallBack';
import { RcpCall } from './RcpCall';
import { RcpUtil } from './RcpUtil';

const RESPONSE_CODE_OK: number = 200;

/**
 * 网络请求入口（对应旧版 com.licq.tv.net.MobileApi）。
 *
 * 回调式（等价旧版 MobileApi.getInstance().getJoke(...).enqueue(new NetInheritObserver<...>(){...})）：
 *   MobileApi.getInstance().getJoke(1, 20, 'video').enqueue({
 *     onSuccess: (bean: BaseBean<JokeBean[]>, errorMsg: string) => {
 *       // bean.result 为段子列表
 *     },
 *     onFail: (msg: string) => {
 *       // msg 为可直接展示的中文错误描述
 *     }
 *   });
 *
 * Promise 式：
 *   const bean = await MobileApi.getInstance().getJoke(1, 20, 'video').result();
 */
export class MobileApi {
  private static instance?: MobileApi;

  private session: rcp.Session = RcpUtil.getSession();

  static getInstance(): MobileApi {
    if (!MobileApi.instance) {
      MobileApi.instance = new MobileApi();
    }
    return MobileApi.instance;
  }

  /** 获取消息通知（旧版 communal4_tabAd → GET member4_notice.xhtml） */
  getNotice(code: string, location: number): RcpCall<BaseBean<object>> {
    const query: Record<string, string> = {
      'code': code,
      'location': location.toString()
    };
    return new RcpCall<BaseBean<object>>(() => this.doGet<BaseBean<object>>(MobileApiUrl.HEALTHCARE_GETNOTICE, query));
  }

  /** 登录（旧版 communal4_tabAdOnly → POST member4_login.xhtml，JSON body） */
  login(userInfo: UserInfo): RcpCall<BaseBean<UserInfo>> {
    return new RcpCall<BaseBean<UserInfo>>(() => this.doPost<UserInfo>(MobileApiUrl.HEALTHCARE_LOGIN, userInfo));
  }

  /** 新实时段子（旧版 getJoke → GET getJoke，参数 page / count / type） */
  getJoke(page: number, count: number, type: string): RcpCall<BaseBean<JokeBean[]>> {
    const query: Record<string, string> = {
      'page': page.toString(),
      'count': count.toString(),
      'type': type
    };
    return new RcpCall<BaseBean<JokeBean[]>>(() => this.doGet<JokeBean[]>(MobileApiUrl.APIOPEN_GETJOKE, query));
  }

  /**
   * 拉取任意地址的文本内容（如 m3u 直播订阅、频道列表文件），不做 BaseBean 解析。
   * url 传完整绝对地址。
   */
  fetchText(url: string): RcpCall<string> {
    return new RcpCall<string>(() => this.doGetText(url));
  }

  private async doGetText(url: string): Promise<string> {
    const resp: rcp.Response = await this.session.get(url);
    if (resp.statusCode === 404) {
      throw new NetError('接口未找到');
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw new NetError(`服务器异常(${resp.statusCode})`);
    }
    const text: string | null = resp.toString();
    if (text === null || text === '') {
      throw new NetError('响应内容为空');
    }
    return text;
  }

  private async doGet<T extends object>(path: string, query: Record<string, string>): Promise<BaseBean<T>> {
    const resp: rcp.Response = await this.session.get(MobileApi.buildUrl(path, query));
    return MobileApi.parseBean<T>(resp);
  }

  private async doPost<T extends object>(path: string, body: object): Promise<BaseBean<T>> {
    const headers: rcp.RequestHeaders = { 'content-type': 'application/json' };
    const content: rcp.RequestContent = { body: JSON.stringify(body) };
    const request: rcp.Request = new rcp.Request(path, 'POST', headers, content);
    const resp: rcp.Response = await this.session.fetch(request);
    return MobileApi.parseBean<T>(resp);
  }

  /** 拼接查询参数（当前 SDK 的 session.get 不提供 urlQuery 能力） */
  private static buildUrl(path: string, query: Record<string, string>): string {
    const keys: string[] = Object.keys(query);
    if (keys.length === 0) {
      return path;
    }
    const parts: string[] = [];
    for (const k of keys) {
      parts.push(`${encodeURIComponent(k)}=${encodeURIComponent(query[k])}`);
    }
    return `${path}?${parts.join('&')}`;
  }

  /** 统一处理 HTTP 状态码、JSON 解析与业务码（对应旧版 NetInheritObserver.onResponse 的拦截逻辑） */
  private static parseBean<T extends object>(resp: rcp.Response): BaseBean<T> {
    if (resp.statusCode === 401 || resp.statusCode === 403) {
      throw new NetError('权限错误');
    }
    if (resp.statusCode === 404) {
      throw new NetError('接口未找到');
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw new NetError(`服务器异常(${resp.statusCode})`);
    }
    let bean: BaseBean<T> | null = null;
    try {
      const obj: object | null = resp.toJSON();
      if (obj !== null) {
        bean = obj as BaseBean<T>;
      }
    } catch (e) {
      throw new NetError('解析错误');
    }
    if (bean === null) {
      throw new NetError('解析错误');
    }
    if (bean.code !== RESPONSE_CODE_OK) {
      throw new NetError(bean.message !== '' ? bean.message : `业务错误(code=${bean.code})`);
    }
    return bean;
  }
}
