#!/usr/bin/env bash
# 直播源快照定时刷新：拉取最新代码 → 运行过滤脚本 → 有变化则提交并推送。
# 建议通过 crontab / launchd / Gitee Go 定时触发，例如每天早上 6:10：
#   10 6 * * * /path/to/TPTV/scripts/cron_refresh.sh >> /tmp/tptv_refresh.log 2>&1
set -e
cd "$(dirname "$0")/.."

BRANCH="${BRANCH:-develop}"
git fetch origin "$BRANCH"
git checkout "$BRANCH"
git pull --ff-only origin "$BRANCH"

python3 scripts/refresh_sources.py --remote

if git status --porcelain -- entry/src/main/resources/rawfile/live_filtered.m3u | grep -q .; then
  git add entry/src/main/resources/rawfile/live_filtered.m3u
  git commit -m "chore: 刷新直播源快照 $(date +%Y-%m-%d)"
  git push origin "$BRANCH"
  echo "[cron_refresh] 快照已更新并推送"
else
  echo "[cron_refresh] 快照无变化"
fi
