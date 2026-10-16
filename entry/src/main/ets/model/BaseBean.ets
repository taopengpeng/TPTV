/**
 * 通用响应实体（对应旧版 com.licq.tv.bean.BaseBean）
 */
export class BaseBean<T> {
  code: number = 0;
  message: string = '';
  result?: T;
}
