import { BusinessError } from '@kit.BasicServicesKit';
import { NetCallBack, NetError, toNetErrorMessage } from './NetCallBack';

/**
 * 请求句柄（对应旧版 retrofit2.Call 的用法）：
 *
 * 回调式（等价旧版 Call.enqueue + NetInheritObserver）：
 *   call.enqueue({
 *     onSuccess: (bean: T, errorMsg: string) => { ... },
 *     onFail: (msg: string) => { ... }
 *   });
 *
 * Promise 式（等价 Call.execute 的异步版）：
 *   const bean = await call.result();  // 失败抛 NetError 或 BusinessError
 */
export class RcpCall<T> {
  private readonly executor: () => Promise<T>;
  private promise: Promise<T> | null = null;

  constructor(executor: () => Promise<T>) {
    this.executor = executor;
  }

  /** 惰性发起请求并返回 Promise，重复调用复用同一次请求 */
  result(): Promise<T> {
    if (this.promise === null) {
      this.promise = this.executor();
    }
    return this.promise;
  }

  /** 回调式发起请求 */
  enqueue(callback: NetCallBack<T>): void {
    if (callback.onSubscribed) {
      callback.onSubscribed(this);
    }
    this.result().then((t: T) => {
      callback.onSuccess(t, '');
    }).catch((e: BusinessError) => {
      const msg = e instanceof NetError ? e.message : toNetErrorMessage(e);
      callback.onFail(msg);
    });
  }

  /**
   * 丢弃本次请求的结果回调（对应旧版 Call.cancel）。
   * 说明：会话与连接由单例 Session 复用，此处不做传输层中断，仅保证不再回调。
   */
  cancel(): void {
    this.promise = null;
  }
}
