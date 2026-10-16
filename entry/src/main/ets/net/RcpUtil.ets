import { rcp } from '@kit.RemoteCommunicationKit';
import { Constants } from './Constants';

const CONNECT_TIMEOUT_MS: number = 10 * 1000;
const TRANSFER_TIMEOUT_MS: number = 30 * 1000;

/**
 * 公共 Header 拦截器（对应旧版 HttpCommonInterceptor）。
 * 需要追加设备型号、token 等公共参数时在此处统一添加。
 */
class CommonHeaderInterceptor implements rcp.Interceptor {
  intercept(context: rcp.RequestContext, next: rcp.RequestHandler): Promise<rcp.Response> {
    const headers = context.request.headers;
    if (headers) {
      headers['accept'] = 'application/json';
      headers['platform'] = 'harmonyos';
    }
    return next.handle(context);
  }
}

/**
 * RCP 会话单例（对应旧版 RetrofitUtil：统一基地址、超时、公共 Header、日志）。
 *
 * 旧版 SSLSocketFactoryUtils 的单向/双向证书校验，RCP 下通过
 * requestConfiguration.security（remoteValidation / 证书配置）实现，接入自有后端时再扩展。
 */
export class RcpUtil {
  private static session?: rcp.Session;

  static getSession(): rcp.Session {
    if (!RcpUtil.session) {
      const headers: rcp.RequestHeaders = { 'accept': 'application/json' };
      const config: rcp.SessionConfiguration = {
        baseAddress: Constants.BASEURL,
        headers: headers,
        interceptors: [new CommonHeaderInterceptor()],
        requestConfiguration: {
          transfer: {
            timeout: {
              connectMs: CONNECT_TIMEOUT_MS,
              transferMs: TRANSFER_TIMEOUT_MS
            }
          }
        }
      };
      RcpUtil.session = rcp.createSession(config);
    }
    return RcpUtil.session;
  }

  /** 应用退出时可调用，释放会话资源 */
  static closeSession(): void {
    if (RcpUtil.session) {
      RcpUtil.session.close();
      RcpUtil.session = undefined;
    }
  }
}
