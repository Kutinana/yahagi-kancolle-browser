# 海域资料发布目录

这个目录保存海域查询功能的可维护源资料和在线更新清单。

## 目录说明

- `source/kcwiki_出击_敌舰配置.xlsx`：敌方舰队、节点与经验等源数据。
- `source/images/`：海域封面、路线图和图片清单。
- `schema/`：资料目录与在线清单的 JSON Schema。
- `manifest.json`：客户端检查更新时读取的轻量清单。
- `dist/`：本地生成的 GitHub Release 压缩包，不提交到 Git。

应用内的 `assets/data/sortie_map_catalog.json` 与
`assets/images/sortie_maps/` 是随安装包提供的兜底快照。用户在设置页手动点击
“海域资料”更新后，应用会从 GitHub Release 下载经过 SHA-256 校验的资料包，
校验并原子切换到本地缓存；下载或安装失败时继续使用之前可用的版本。

## 更新流程

1. 替换 `source/` 下的 Excel 与图片。
2. 更新 `tool/build_sortie_map_assets.py` 中的数据版本、修订号和发布时间。
3. 生成并检查随包资源：

   ```powershell
   python tool/build_sortie_map_assets.py
   python -m unittest tool.test_build_sortie_map_assets -v
   ```

4. 生成确定性发布包和 `manifest.json`：

   需要 Python 的 Pillow 包（`python -m pip install pillow`）。内容有变化时，
   必须提高 catalog 的 `revision`，并使用新的 `dataVersion`，以生成新的 Release
   标签和 ZIP 文件名。生成器会拒绝超出客户端容量或无法安装的资料。

   ```powershell
   python tool/build_sortie_release.py
   python -m unittest tool.test_build_sortie_release -v
   ```

   发布前从仓库根目录运行客户端契约验收：

   ```powershell
   $env:YAHAGI_RELEASE_CONTRACT_TEST = '1'
   flutter test test/data_release_contract_test.dart
   ```

5. 先在 [资料专用仓库](https://github.com/yamatosaki/yahagi-kancolle-data) 创建清单中 `archive.tag` 对应的 GitHub Release，并上传
   `data/sortie/dist/` 中名称与 `archive.fileName` 完全相同的 ZIP；下载复验
   文件大小与 SHA-256 后，再提交并推送源资料、随包快照与 `manifest.json`。
   这样客户端永远不会先读到一个尚未可下载的发布清单。

   推送清单后执行真实下载与安装验收：

   ```powershell
   $env:YAHAGI_LIVE_DATA_TEST = '1'
   flutter test test/data_release_live_test.dart
   ```

发布前不要修改已发布标签下的文件；需要修正时应提高 `revision` 并使用新版本号和新标签。
