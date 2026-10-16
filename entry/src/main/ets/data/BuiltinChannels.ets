import { LiveChannel } from '../model/LiveChannel';

/**
 * 内置兜底直播频道（2026-09 实测可用，来自 iptv-org 公共索引）。
 * 直播源时效性强，失效属正常现象，可在直播页配置 m3u 订阅地址刷新替换。
 */
export class BuiltinChannels {
  static all(): LiveChannel[] {
    const list: LiveChannel[] = [
      // 央视
      new LiveChannel('CCTV-1 综合', 'http://74.91.26.218:82/live/cctv1hd.m3u8', '央视'),
      new LiveChannel('CCTV-2 财经', 'http://74.91.26.218:82/live/cctv2hd.m3u8', '央视'),
      new LiveChannel('CCTV-3 综艺', 'http://74.91.26.218:82/live/cctv3hd.m3u8', '央视'),
      new LiveChannel('CCTV-5+ 体育赛事', 'https://myip.pdtvhd.com/Sports/streams/CCTV5pul.m3u8', '央视'),
      new LiveChannel('CCTV-7 国防军事', 'http://74.91.26.218:82/live/cctv7hd.m3u8', '央视'),
      new LiveChannel('CCTV-8 电视剧', 'http://74.91.26.218:82/live/cctv8hd.m3u8', '央视'),
      new LiveChannel('CCTV-9 纪录', 'https://xykt-fix.github.io/Y77.m3u8', '央视'),
      new LiveChannel('CCTV-10 科教', 'http://74.91.26.218:82/live/cctv10hd.m3u8', '央视'),
      new LiveChannel('CCTV-11 戏曲', 'http://74.91.26.218:82/live/cctv11hd.m3u8', '央视'),
      new LiveChannel('CCTV-12 社会与法', 'http://74.91.26.218:82/live/cctv12hd.m3u8', '央视'),
      new LiveChannel('CCTV-13 新闻', 'http://74.91.26.218:82/live/cctv13hd.m3u8', '央视'),
      new LiveChannel('CCTV-14 少儿', 'http://74.91.26.218:82/live/cctv14hd.m3u8', '央视'),
      new LiveChannel('CCTV-15 音乐', 'https://xykt-fix.github.io/play/a02e/index.m3u8', '央视'),
      new LiveChannel('CCTV-17 农业农村', 'http://74.91.26.218:82/live/cctv17hd.m3u8', '央视'),
      // 卫视 / 地方
      new LiveChannel('湖南卫视', 'http://hlsal-ldvt.qing.mgtv.com/nn_live/nn_x64/dWlwPTEyNy4wLjAuMSZ1aWQ9cWluZy1jbXMmbm5fdGltZXpvbmU9OCZjZG5leF9pZD1hbF9obHNfbGR2dCZ1dWlkPTliODY4NmU5ZTM2YzYwMmMmZT02OTE0NjA0JnY9MSZpZD1ITldTWkdTVCZzPTcwN2RiYTc2YzJjNmJmMTQ4MmUyZGYzOWU2NWM3YWFi/HNWSZGST.m3u8', '卫视'),
      new LiveChannel('河北卫视', 'https://event.pull.hebtv.com/live/live101.m3u8', '卫视'),
      new LiveChannel('安徽卫视', 'https://restream.pdtvhd.com/memfs/c1cd2ed0-3b2b-4c25-af98-a7fb0b1eb130.m3u8', '卫视'),
      new LiveChannel('东方卫视国际', 'https://restream.pdtvhd.com/memfs/0b1b95c9-3543-4af9-9fdb-cf45f1602f17.m3u8', '卫视'),
      new LiveChannel('浙江卫视国际', 'https://ali-m-l.cztv.com/channels/lantian/channel10/1080p.m3u8', '卫视'),
      new LiveChannel('广州综合', 'https://tencentplaybusiness.gztv.com/live/zonghes.m3u8', '地方'),
      new LiveChannel('CCTV+ 新闻1', 'https://cd-live-stream.news.cctvplus.com/live/smil:CHANNEL1.smil/playlist.m3u8', '地方')
    ];
    return list;
  }
}
