import { BusinessError } from '@kit.BasicServicesKit';

/**
 * 可取消的请求句柄（对应旧版 retrofit2.Call 的 cancel 能力）
 */
export interface CancellableCall {
  cancel(): void;
}

/**
 * 统一网络回调（对应旧版 com.licq.tv.net.NetCallBack / RxNetObserver）：
 * - onSubscribed：请求发起后回调，可把句柄存入队列，界面销毁时统一 cancel，防泄漏
 * - onSuccess：业务成功（HTTP 2xx 且 BaseBean.code == 200）
 * - onFail：失败，msg 为可直接展示的中文描述
 */
export interface NetCallBack<T> {
  onSubscribed?(call: CancellableCall): void;
  onSuccess(t: T, errorMsg: string): void;
  onFail(msg: string): void;
}

/**
 * 本封装层抛出的业务/HTTP 错误，message 即友好中文描述
 */
export class NetError extends Error {
  constructor(message: string) {
    super(message);
  }
}

/**
 * RCP 错误码 → 中文描述（对应旧版 RxNetObserver.error 的异常翻译）。
 * 错误码参考《Remote Communication Kit 错误码》文档，未覆盖的情况走默认分支并携带原始信息。
 */
export function toNetErrorMessage(e: BusinessError): string {
  switch (e.code) {
    case 201:
      return '权限错误：请确认已申请 ohos.permission.INTERNET';
    case 401:
      return '参数错误';
    case 1007901: // 无效 URL
      return '请求地址无效';
    case 1007902: // URL scheme 不支持
      return '不支持的请求协议';
    case 1007903: // DNS 解析失败
      return '域名解析失败，请检查网络';
    case 1007904: // 无法连接服务器
      return '网络连接失败';
    case 1007905: // TLS/SSL 握手错误
      return '安全证书异常';
    case 1007906: // 请求超时
      return '请求超时';
    default:
      return `请求出错(${e.code})：${e.message}`;
  }
}
