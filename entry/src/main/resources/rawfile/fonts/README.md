# TPTV 本地展示字体

- `Sora-SemiBold.ttf`：Sora 官方静态字体，用于 TPTV 品牌名称。
  来源：[Sora 官方字体](https://github.com/sora-xor/sora-font/tree/master/fonts/ttf)
  许可：`Sora-OFL.txt`（SIL OFL 1.1）。
- `TPTVDisplay.otf`：思源宋体 CN Medium 的标题字形子集，仅用于“电视直播”。
  来源：[思源宋体官方字体](https://github.com/adobe-fonts/source-han-serif/tree/release/SubsetOTF/CN)
  许可：`SourceHanSerif-LICENSE.txt`（SIL OFL 1.1）。
  子集通过 fonttools 生成，并移除原字体名称，避免沿用保留名称。

字体随应用打包，不请求远端字体。注册失败时回退系统字体。
中文展示标题变更时需重新生成子集；操作按钮、说明与频道名称使用系统字体。
