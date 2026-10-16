import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { VideoItem } from '../model/VideoItem';

/**
 * 自定义点播片源的持久化存储（preferences，按行存储 title|url）。
 */
export class VideoStore {
  private static readonly PREF_NAME: string = 'videoSettings';
  private static readonly KEY_CUSTOM: string = 'custom_videos';

  static load(context: common.UIAbilityContext): VideoItem[] {
    const prefs = preferences.getPreferencesSync(context, { name: VideoStore.PREF_NAME });
    const text: preferences.ValueType = prefs.getSync(VideoStore.KEY_CUSTOM, '');
    const result: VideoItem[] = [];
    if (typeof text === 'string' && text !== '') {
      for (const line of text.split('\n')) {
        const sep = line.indexOf('|');
        if (sep > 0 && sep < line.length - 1) {
          const title = line.substring(0, sep);
          const url = line.substring(sep + 1);
          result.push(VideoItem.online(title, url, '自定义片源'));
        }
      }
    }
    return result;
  }

  static save(context: common.UIAbilityContext, list: VideoItem[]): void {
    const prefs = preferences.getPreferencesSync(context, { name: VideoStore.PREF_NAME });
    const lines: string[] = [];
    for (const item of list) {
      lines.push(`${item.title}|${item.url}`);
    }
    prefs.putSync(VideoStore.KEY_CUSTOM, lines.join('\n'));
    prefs.flushSync();
  }
}
