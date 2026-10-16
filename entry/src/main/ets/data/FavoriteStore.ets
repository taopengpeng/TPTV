import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { ChannelFilter } from '../model/ChannelFilter';
import { LiveChannel } from '../model/LiveChannel';

const PREF_NAME: string = 'liveSettings';
const KEY_FAVS: string = 'fav_keys';
const KEY_HISTORY: string = 'history_lines';
const HISTORY_CAP: number = 50;

/**
 * 历史记录条目
 */
export class HistoryItem {
  name: string = '';
  url: string = '';
  group: string = '';
  time: number = 0;
}

/**
 * 收藏与历史（preferences 行式存储，与 VideoStore 同风格）：
 * - 收藏：频道归一化 key，每行一个
 * - 历史：`time|name|group|url`，按时间倒序，上限 50 条
 */
export class FavoriteStore {
  static favKeys(context: common.UIAbilityContext): string[] {
    const options: preferences.Options = { name: PREF_NAME };
    const prefs = preferences.getPreferencesSync(context, options);
    const raw: preferences.ValueType = prefs.getSync(KEY_FAVS, '');
    if (typeof raw !== 'string' || raw === '') {
      return [];
    }
    return raw.split('\n').filter((k: string) => k !== '');
  }

  static isFav(context: common.UIAbilityContext, key: string): boolean {
    return FavoriteStore.favKeys(context).includes(key);
  }

  /** 切换收藏状态，返回切换后是否已收藏 */
  static toggle(context: common.UIAbilityContext, key: string): boolean {
    const keys = FavoriteStore.favKeys(context);
    const idx = keys.indexOf(key);
    if (idx >= 0) {
      keys.splice(idx, 1);
    } else {
      keys.unshift(key);
    }
    const options: preferences.Options = { name: PREF_NAME };
    const prefs = preferences.getPreferencesSync(context, options);
    prefs.putSync(KEY_FAVS, keys.join('\n'));
    prefs.flushSync();
    return idx < 0;
  }

  static history(context: common.UIAbilityContext): HistoryItem[] {
    const options: preferences.Options = { name: PREF_NAME };
    const prefs = preferences.getPreferencesSync(context, options);
    const raw: preferences.ValueType = prefs.getSync(KEY_HISTORY, '');
    const result: HistoryItem[] = [];
    if (typeof raw !== 'string' || raw === '') {
      return result;
    }
    for (const line of raw.split('\n')) {
      const parts = line.split('|');
      if (parts.length < 4) {
        continue;
      }
      const item = new HistoryItem();
      item.time = Number(parts[0]);
      item.name = parts[1];
      item.group = parts[2];
      item.url = parts.slice(3).join('|');
      if (item.url !== '') {
        result.push(item);
      }
    }
    result.sort((a: HistoryItem, b: HistoryItem) => b.time - a.time);
    return result;
  }

  /** 记录播放历史：同名频道只保留最新一条，置顶并截断到上限 */
  static addHistory(context: common.UIAbilityContext, ch: LiveChannel): void {
    const key = ChannelFilter.normalizeKey(ch.name);
    const list = FavoriteStore.history(context)
      .filter((h: HistoryItem) => ChannelFilter.normalizeKey(h.name) !== key);
    const item = new HistoryItem();
    item.name = ch.name;
    item.url = ch.url;
    item.group = ch.group;
    item.time = Date.now();
    list.unshift(item);
    const capped = list.slice(0, HISTORY_CAP);
    const text = capped.map((h: HistoryItem) => `${h.time}|${h.name}|${h.group}|${h.url}`).join('\n');
    const options: preferences.Options = { name: PREF_NAME };
    const prefs = preferences.getPreferencesSync(context, options);
    prefs.putSync(KEY_HISTORY, text);
    prefs.flushSync();
  }
}
