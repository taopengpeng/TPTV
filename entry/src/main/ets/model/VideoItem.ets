/**
 * 视频条目。本地资源填 rawFile（entry/src/main/resources/rawfile 下的文件名），
 * 在线资源填 url（HTTPS，播放需 ohos.permission.INTERNET，见 module.json5），
 * 直播频道填 url 且 isLive = true（播放页隐藏进度条并提供换台）。
 */
export class VideoItem {
  title: string;
  desc: string;
  rawFile: string;
  url: string;
  isLive: boolean;
  custom: boolean;

  constructor(title: string, desc: string = '', rawFile: string = '', url: string = '', isLive: boolean = false, custom: boolean = false) {
    this.title = title;
    this.desc = desc;
    this.rawFile = rawFile;
    this.url = url;
    this.isLive = isLive;
    this.custom = custom;
  }

  static local(title: string, rawFile: string, desc: string): VideoItem {
    return new VideoItem(title, desc, rawFile, '');
  }

  static online(title: string, url: string, desc: string): VideoItem {
    return new VideoItem(title, desc, '', url);
  }

  static live(title: string, url: string, desc: string): VideoItem {
    return new VideoItem(title, desc, '', url, true);
  }
}
