import { LiveChannel } from './LiveChannel';

/**
 * 直播相关共享上下文：
 * - channels/currentIndex：播放页遥控器换台与失效换源使用（播放列表 = 过滤后的结果）
 * - fullChannels：过滤前的完整源列表（保留备用，可随时重新过滤）
 */
export class LiveStore {
  static channels: LiveChannel[] = [];
  static currentIndex: number = 0;
  static fullChannels: LiveChannel[] = [];
}
