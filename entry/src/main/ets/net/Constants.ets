/**
 * 全局网络配置常量（对应旧版 com.licq.tv.utils.Constants）
 */
export class Constants {
  /**
   * 服务基地址。注意：apiopen.top 的 JSON 接口已下线（2026-09 实测统一返回 HTML 官网页面），
   * 接入自有后端时只需修改此地址，封装层无需变动。
   */
  static readonly BASEURL: string = 'https://api.apiopen.top/';
}
