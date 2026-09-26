# 敌舰资料库

此目录维护“海域查询”使用的独立敌舰资料库。

- `source/kancolle_enemy_database.xlsx`：人工维护的开发源文件，不由 App 直接读取。
- `../../assets/data/enemy_catalog.json`：随 App 内置、运行时读取的 JSON 快照。
- `manifest.json`：设置页“敌舰资料”更新入口读取的版本、大小和 SHA-256。
- `schema/`：JSON 格式约束。

更新流程：替换 Excel → 运行 `tool/build_enemy_catalog.py` → 运行
`tool/build_enemy_release.py` → 执行测试 → 在[资料专用仓库](https://github.com/yamatosaki/yahagi-kancolle-data)创建 GitHub Release 并上传
`enemy_catalog.json` → 提交并推送 `manifest.json`。客户端会校验版本、文件大小、
SHA-256、记录数量和别名数量，校验通过后才原子替换本地缓存；失败时继续使用原资料。

内容变化时，先在生成器中提高 `revision`，再为 `build_enemy_release.py --tag` 指定新标签；
生成器会拒绝沿用旧修订号或旧 Release 地址。上传前从仓库根目录运行
`python -m unittest tool.test_build_enemy_release -v` 和
`dart run tool/verify_data_release.dart --local-only`，让真实 Dart 运行时验证本地发布包。
上传海域和敌舰两份资产后、推送清单前，再运行
`dart run tool/verify_data_release.dart`，核对正式资产的大小、SHA-256 和源内容。
跨语言验收会同时构建海域 ZIP，需要 Python 的 Pillow 包（`python -m pip install pillow`）。
上传资产、推送清单后，设置 `YAHAGI_LIVE_DATA_TEST=1` 运行
`flutter test test/data_release_live_test.dart`，验证实际下载和重启读取。

地图敌舰条目中的 ID 是头像 ID，不一定是精确配置 ID。生成器使用“头像 ID + 地图配置名”
建立别名，详情卡最终解析到资料库中的具体配置记录。
