# TPTV

> 基于 **HarmonyOS NEXT（Stage 模型 + ArkTS）** 的电视直播与视频播放演示应用，支持 TV / 手机 / 平板。

项目仓库：https://github.com/taopengpeng/TPTV

**搜索关键词**：HarmonyOS NEXT ・ 鸿蒙 ・ ArkTS ・ Stage 模型 ・ DevEco Studio ・ AVPlayer ・ XComponent ・ HLS / m3u8 ・ IPTV ・ 电视直播 ・ 直播源 ・ 切换播放源 ・ RCP ・ RemoteCommunicationKit ・ TV 应用开发

---

## ✨ 功能特性

### 📺 电视直播（重点）

- **300+ 频道开箱即用**：内置经全量测活的预过滤源快照（`rawfile/live_filtered.m3u`），启动零等待，无需任何配置
- **一个频道一条，备源不占列表**：列表干净无重复；每频道最多 3 路源，多源频道带 `N源` 角标
- **播放页一键切源**：`切源 n/m` 按钮手动循环切换；播放失败 / 起播超时 10 秒自动切换备用源（连续 5 次失败才提示）
- **分类 + 搜索**：央视 / 卫视 / 港澳台 / 专题 / 地方 分类标签，可与关键词搜索叠加
- **全部源视图**：过滤前 1700+ 条原始源同样可按分类浏览，带 `已验证 / 未验证` 标注
- **m3u 订阅**：自定义订阅地址自动解析（去重 → 测活 → 每频道保留 3 个可用源），订阅原文本地留存
- **TV 遥控器适配**：上下键循环换台、焦点导航；手机端支持全屏横屏

### 🎬 点播播放

- 本地 rawfile 视频 + 在线 MP4 / HLS 片源，自定义片源可持久化保存
- `AVPlayer` + `XComponent(surface)`：播放/暂停、进度拖动、循环、倍速比例渲染（letterbox）、屏幕常亮、加载/失败提示

### 🌐 网络层（RCP）

- 基于 `@kit.RemoteCommunicationKit` 的等价封装：单例会话、公共 Header 拦截器、连接/传输超时
- 统一回调（`NetCallBack`：成功/失败/错误码中文映射）与 Promise 双用法，接口风格对齐经典 Retrofit 三层封装

## 🛠 技术栈

| 项 | 说明 |
| --- | --- |
| 应用模型 | HarmonyOS **Stage 模型**，API 12+（DevEco Studio 5.0 ~ 6.x 实测可构建） |
| 语言/UI | **ArkTS** + 声明式 ArkUI |
| 媒体播放 | `@kit.MediaKit` AVPlayer + XComponent(surface)，本地 rawfile / HTTP-HLS 直播 |
| 网络请求 | `@kit.RemoteCommunicationKit`（RCP） |
| 数据持久化 | `@kit.ArkData` preferences、`@kit.CoreFileKit` 文件 |
| 构建 | hvigor（工程含完整 Stage 模型配置：AppScope / module.json5 / oh-package） |

## 🚀 快速开始

1. 安装 [DevEco Studio 5.0](https://developer.huawei.com/consumer/cn/deveco-studio/) 及以上版本
2. `File > Open` 打开本工程，等待 hvigor Sync 完成
3. `File > Project Structure > Signing Configs` 勾选自动签名（需登录华为账号）
4. 连接真机（TV / 手机 / 平板）点击 Run

命令行构建：`hvigorw assembleHap`（需配置 `DEVECO_SDK_HOME` 指向 DevEco 内置 SDK）。

## 📡 直播源说明与来源

- 内置播放列表为**预过滤快照**：由 `scripts/refresh_sources.py` 对多份公开源仓库全量去重、测活后生成（2026-09-16：1762+145 个源 → 约 320 个可用频道），生成脚本流程：多仓库拉取 → URL 去重 → 名称归一化分组 → 并发测活 → 每频道保留 ≤3 个可用源。
- **刷新快照**（Python 3.8+，仅标准库）：

  ```bash
  python3 scripts/refresh_sources.py             # 使用仓库内原始快照（离线）
  python3 scripts/refresh_sources.py --remote    # 额外拉取 6 个公共源仓库的最新清单
  ```

- **定时自动刷新**：`scripts/cron_refresh.sh` 会拉取最新代码、执行过滤脚本并在快照有变化时自动提交推送。配置 crontab 每日执行即可（也可接入 Gitee Go / GitHub Actions，若镜像到 GitHub 可用 Actions schedule）：

  ```bash
  10 6 * * * /path/to/TPTV/scripts/cron_refresh.sh >> /tmp/tptv_refresh.log 2>&1
  ```

- 来源均为 **GitHub 公开开源索引项目**：`iptv-org/iptv`、`Guovin/iptv-api`、`vbskycn/iptv`、`YanG-1989/m3u`、`fanmingming/live` 等。本项目不抓取、不破解任何私有/付费内容。
- 直播源时效性强（公共源随时失效属正常现象）。刷新方式：执行上述脚本重新生成快照，或在 App 内配置 m3u 订阅地址在线过滤。
- 过滤前的完整原始快照同样保留在 `rawfile/`（`live_guovin.m3u`、`live_vbskycn.m3u`），可在 App「全部源」视图中查看。

## ⚠️ 免责声明（重要）

1. **本项目仅供学习研究**，目的是演示 HarmonyOS Stage 模型 / ArkTS / AVPlayer / RCP 等开发技术。项目**不提供任何影视内容**，不存储、不制作、不传播任何受版权保护的音视频文件。
2. 仓库及内置快照中的频道地址全部来自**公共互联网的开源聚合索引**，本项目未对其合法性、授权状态做任何验证；地址的可用性与合法性不代表本项目立场。
3. **严禁**将本项目或其构建产物用于任何商业用途，或向公众分发、诱导用户观看未经授权的内容。请在下载后 24 小时内自行评估并删除，使用行为须符合所在国家/地区的法律法规。
4. 若你是相关内容的权利人，认为本仓库引用的地址侵犯了你的合法权益，请通过 Issue 或仓库主页联系方式告知，**核实后将立即移除**相关内容。
5. 因使用本项目而产生的任何直接或间接后果，由使用者自行承担；本项目开发者不承担任何法律责任。

## 📂 工程结构

```
TPTV/
├── AppScope/                        # 应用级配置（app.json5 / 图标 / 应用名）
├── build-profile.json5              # 工程级构建配置（SDK / 模块）
├── hvigorfile.ts + hvigor/          # hvigor 构建脚本与配置
├── oh-package.json5                 # 依赖管理
└── entry/src/main/
    ├── module.json5                 # 设备类型（tv/phone/tablet）、权限、Ability
    ├── ets/
    │   ├── entryability/EntryAbility.ets
    │   ├── pages/                   # Index 点播 / Live 直播 / Player 播放
    │   ├── model/                   # 实体与解析（M3uParser / ChannelFilter / LiveStore …）
    │   ├── data/                    # LiveCatalog 预过滤快照加载 / BuiltinChannels 兜底
    │   └── net/                     # RCP 网络层（RcpUtil / RcpCall / NetCallBack / MobileApi）
    └── resources/rawfile/           # video.mp4 + 直播源快照（filtered + 原始留存）
```

## 📦 从旧版（Gradle + Java FA 模型）迁移要点

| 旧版 | 新版 |
| --- | --- |
| 两个 Ability（Main / Videoplayer） | 单 `EntryAbility` + 路由页面（Index / Live / Player） |
| `ohos.media.player.Player` + SurfaceProvider | `AVPlayer` + `XComponent` |
| okhttp + retrofit（服务已停运） | RCP 等价封装（见 `ets/net/`） |
| `ListContainer` + RecycleItemProvider | ArkUI `List` + `ForEach` |
| `resources/rawfile/video.mp4` | 保留，改用 `resourceManager.getRawFdSync()` 加载 |

## 🤝 参与贡献 & 许可证

1. Fork 本仓库 → 新建 `Feat_xxx` 分支 → 提交 PR
2. 欢迎补充：直播源测活脚本参数化、EPG 节目单、频道 Logo、CCTV 完整源
3. 本项目基于 [木兰宽松许可证第 2 版（Mulan PSL-2.0）](./LICENSE) 开源
