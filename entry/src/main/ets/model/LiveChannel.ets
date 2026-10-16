/**
 * 直播频道条目。url 为明文 HLS（m3u8）地址，AVPlayer 可直接播放。
 * 播放列表中每个频道只显示一条（主源），其余可用源挂在 alts 里，
 * 供播放页手动切换与失效自动兜底。logo 为频道台标图（可为空）。
 */
export class LiveChannel {
  name: string;
  url: string;
  group: string;
  logo: string;
  alts: LiveChannel[];

  constructor(name: string, url: string, group: string, logo: string = '') {
    this.name = name;
    this.url = url;
    this.group = group;
    this.logo = logo;
    this.alts = [];
  }
}
