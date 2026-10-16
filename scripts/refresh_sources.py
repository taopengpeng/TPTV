#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
直播源刷新脚本（本项目预过滤快照的生成器）。

流程：拉取多份公共 m3u 清单（可选）+ 本地原始快照 + 内置频道
  → URL 去重
  → 名称归一化分组（同名频道归并，如 "CCTV-1 (1080p)" 与 "CCTV1"）
  → 并发测活（HTTP 2xx 且内容为 #EXTM3U / 直连 TS）
  → 每频道按原顺序保留前 KEEP 个可用源
  → 生成 entry/src/main/resources/rawfile/live_filtered.m3u

用法：
  python3 scripts/refresh_sources.py                     # 本地快照 + 内置频道（离线）
  python3 scripts/refresh_sources.py --remote            # 额外拉取 REMOTE_LISTS 远程清单
  python3 scripts/refresh_sources.py --keep 3 --workers 60 --timeout 7

仅依赖 Python 3.8+ 标准库。上游清单几乎每日更新，建议定期执行以刷新快照。
注意：公共源仅供学习研究，请遵守所在地区法律法规，勿用于商业分发。
"""

import argparse
import concurrent.futures
import glob
import json
import os
import re
import socket
import sys
import time
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW_DIR = os.path.join(ROOT, 'entry', 'src', 'main', 'resources', 'rawfile')
BUILTIN_ETS = os.path.join(ROOT, 'entry', 'src', 'main', 'ets', 'data', 'BuiltinChannels.ets')
OUT_FILE = os.path.join(RAW_DIR, 'live_filtered.m3u')

# 本地保留的原始快照（过滤前数据的留存，见 README「直播源说明与来源」）
RAW_FILES = ['live_guovin.m3u', 'live_vbskycn.m3u']

# 公共开源索引清单（GitHub 公开仓库，几乎每日自动更新；--remote 时拉取）
REMOTE_LISTS = {
    'iptv-org-cn': 'https://iptv-org.github.io/iptv/countries/cn.m3u',
    'suxuang-ipv4': 'https://raw.githubusercontent.com/suxuang/myIPTV/main/ipv4.m3u',
    'vbskycn-iptv4': 'https://raw.githubusercontent.com/vbskycn/iptv/master/tv/iptv4.m3u',
    'guovin-result': 'https://raw.githubusercontent.com/Guovin/iptv-api/gd/output/result.m3u',
    'yang-gather': 'https://raw.githubusercontent.com/YanG-1989/m3u/main/Gather.m3u',
    'fanmingming-ipv6': 'https://live.fanmingming.com/tv/m3u/ipv6.m3u',
}


def parse_m3u(text):
    """解析 m3u 文本，返回 [(标题, 分组, 地址, logo)]，兼容 CRLF 与缺失属性。"""
    entries = []
    name = group = logo = ''
    for line in text.splitlines():
        line = line.strip()
        if line.startswith('#EXTINF'):
            m = re.search(r',(.*)$', line)
            name = m.group(1).strip() if m else ''
            g = re.search(r'group-title="([^"]*)"', line)
            group = g.group(1).strip() if g else ''
            lo = re.search(r'tvg-logo="([^"]*)"', line)
            logo = lo.group(1).strip() if lo else ''
        elif line and not line.startswith('#'):
            if name:
                entries.append((name, group, line, logo))
            name = group = logo = ''
    return entries


def normalize(name):
    """名称归一化：去括号内容/清晰度修饰/分隔符，使同名频道归并为一组。"""
    key = name.lower()
    key = re.sub(r'（[^）]*）|\([^)]*\)|【[^】]*】|\[[^\]]*\]', '', key)
    key = re.sub(r'1080p|720p|480p|4k|8k|fhd|uhd|hdr|超高清|超清|高清|蓝光|标清', '', key)
    key = re.sub(r'[^a-z0-9\u4e00-\u9fa5]+', '', key)
    return key if key else name


def load_builtin():
    """从 BuiltinChannels.ets 提取人工验证频道，保证与 App 内置数据一致。"""
    path = BUILTIN_ETS
    if not os.path.exists(path):
        return []
    ets = open(path, encoding='utf-8').read()
    found = re.findall(r"new LiveChannel\('([^']+)',\s*'([^']+)',\s*'([^')]+)'\)", ets)
    return [(n, g, u) for (n, u, g) in found]


def fetch(url, timeout):
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0', 'Connection': 'close'})
    with urllib.request.urlopen(req) as resp:
        if resp.status < 200 or resp.status >= 300:
            return False
        if url.endswith('.ts'):
            return True
        head = resp.read(800).decode('utf-8', 'ignore')
        return '#EXTM3U' in head


def probe(url, timeout):
    """测活：HTTP 2xx 且内容为 HLS 播放列表（或直连 TS）。任何异常视为不可用。"""
    old = socket.getdefaulttimeout()
    try:
        socket.setdefaulttimeout(timeout)
        return fetch(url, timeout)
    except Exception:
        return False
    finally:
        socket.setdefaulttimeout(old)


def probe_all(urls, workers, timeout, retries):
    """并发测活，失败源按轮数重试；返回 {url: 是否可用}。"""
    results = {}
    todo = list(dict.fromkeys(urls))
    t0 = time.time()
    for round_no in range(1, retries + 1):
        pending = [u for u in todo if not results.get(u)]
        if not pending:
            break
        print(f'  测活第 {round_no} 轮：{len(pending)} 个源 ...')
        done = 0
        with concurrent.futures.ThreadPoolExecutor(workers) as pool:
            futures = {pool.submit(probe, u, timeout): u for u in pending}
            for fut in concurrent.futures.as_completed(futures):
                u = futures[fut]
                try:
                    results[u] = results.get(u) or fut.result()
                except Exception:
                    results.setdefault(u, False)
                done += 1
                if done % 300 == 0:
                    print(f'    进度 {done}/{len(pending)}，已耗时 {time.time() - t0:.0f}s')
    return results


def main():
    ap = argparse.ArgumentParser(description='直播源去重测活与快照生成')
    ap.add_argument('--remote', action='store_true', help='额外拉取 REMOTE_LISTS 远程清单')
    ap.add_argument('--keep', type=int, default=3, help='每频道保留的可用源数量（默认 3）')
    ap.add_argument('--workers', type=int, default=60, help='并发探测线程数（默认 60）')
    ap.add_argument('--timeout', type=float, default=7.0, help='单源探测超时秒数（默认 7）')
    ap.add_argument('--retries', type=int, default=2, help='失败重试轮数（默认 2）')
    args = ap.parse_args()

    sources = []
    # 1) 本地原始快照（过滤前数据的留存）
    for f in RAW_FILES:
        path = os.path.join(RAW_DIR, f)
        if os.path.exists(path):
            got = parse_m3u(open(path, encoding='utf-8', errors='ignore').read())
            print(f'本地 {f}: {len(got)} 条')
            sources += got
    # 2) 内置人工频道（与 App 内 BuiltinChannels 保持一致）
    builtin = load_builtin()
    print(f'内置频道: {len(builtin)} 条')
    sources += [(n, g, u, '') for (n, g, u) in builtin]
    # 3) 远程清单（可选）
    if args.remote:
        for name, url in REMOTE_LISTS.items():
            try:
                req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
                text = urllib.request.urlopen(req, timeout=30).read().decode('utf-8', 'ignore')
                got = parse_m3u(text)
                print(f'远程 {name}: {len(got)} 条')
                sources += got
            except Exception as exc:
                print(f'远程 {name}: 拉取失败（{exc}），跳过')

    # URL 去重
    seen, merged = set(), []
    for name, group, url, _logo in sources:
        if url and url not in seen:
            seen.add(url)
            merged.append((name, group, url, _logo))
    print(f'URL 去重后: {len(merged)} 条')

    # 名称归一化分组
    order, groups = [], {}
    for name, group, url, _logo in merged:
        key = normalize(name)
        if re.fullmatch(r'\d+', key):
            continue  # 过滤日期/时间戳等被误标为频道的垃圾条目
        if key not in groups:
            groups[key] = []
            order.append(key)
        groups[key].append((name, group, url, _logo))
    print(f'归一化分组: {len(order)} 个频道')

    # 并发测活
    all_urls = [e[2] for k in order for e in groups[k]]
    print(f'开始测活: {len(all_urls)} 个源（{args.workers} 并发 / {args.timeout}s 超时 / 重试 {args.retries} 轮）')
    t0 = time.time()
    results = probe_all(all_urls, args.workers, args.timeout, args.retries)
    print(f'测活完成，耗时 {time.time() - t0:.0f}s，可用 {sum(results.values())} / {len(all_urls)}')

    # 每频道保留前 KEEP 个可用源
    out = ['#EXTM3U']
    kept_channels = kept_entries = 0
    for key in order:
        alive = [e for e in groups[key] if results.get(e[2])]
        if not alive:
            continue
        kept_channels += 1
        for (n, g, u, logo) in alive[:args.keep]:
            g_esc = (g or '其他').replace('"', '')
            logo_attr = f' tvg-logo="{logo}"' if logo else ''
            out.append(f'#EXTINF:-1 tvg-name="{n}"{logo_attr} group-title="{g_esc}",{n}')
            out.append(u)
            kept_entries += 1

    with open(OUT_FILE, 'w', encoding='utf-8') as fh:
        fh.write('\n'.join(out) + '\n')
    print(f'生成 {OUT_FILE}')
    print(f'结果: {kept_channels} 个频道 / {kept_entries} 条源（App 启动直接加载，零等待）')
    return 0


if __name__ == '__main__':
    sys.exit(main())
