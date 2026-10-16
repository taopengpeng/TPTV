import { LiveChannel } from './LiveChannel';

/**
 * 最小化 M3U/M3U8 播放列表解析器：
 * 提取 #EXTINF 的标题、tvg-logo 与 group-title 属性，
 * 其后第一个非注释行作为流地址。
 */
export class M3uParser {
  static parse(text: string): LiveChannel[] {
    const channels: LiveChannel[] = [];
    const lines: string[] = text.split(/\r?\n/);
    let name: string = '';
    let group: string = '';
    let logo: string = '';
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i].trim();
      if (line.startsWith('#EXTINF')) {
        name = M3uParser.titleOf(line);
        group = M3uParser.attrOf(line, 'group-title');
        logo = M3uParser.attrOf(line, 'tvg-logo');
      } else if (line.length > 0 && !line.startsWith('#')) {
        if (name !== '') {
          channels.push(new LiveChannel(name, line, group, logo));
        }
        name = '';
        group = '';
        logo = '';
      }
    }
    return channels;
  }

  private static titleOf(line: string): string {
    const idx = line.lastIndexOf(',');
    return idx >= 0 ? line.substring(idx + 1).trim() : '';
  }

  private static attrOf(line: string, key: string): string {
    const marker = key + '="';
    const start = line.indexOf(marker);
    if (start < 0) {
      return '';
    }
    const from = start + marker.length;
    const end = line.indexOf('"', from);
    return end > from ? line.substring(from, end) : '';
  }
}
