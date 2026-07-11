# 晨雾账簿性能验收

本目录记录可复现的性能验收边界，不把模拟器结果当作 ARM64 真机认证。
当前被测页面功能、内容、文案和交互严格保持 `ce04b3c`，晨雾浮签只替换视觉与通用浮层材质。

- SQLite 严格夹具：`flutter test --dart-define=LEDGER_SQL_STRICT=true test/performance/ledger_sqlite_performance_test.dart`
- ARM64 帧时命令：见 `integration_test/README.md`
- `profile-x86-emulator.json` 是 2026-07-11 在 Android 16 x86_64 模拟器 profile mode 上，针对当前 `ce04b3c + 晨雾浮签` 的 1,738 帧重新实测；其 `certified` 固定为 `false`。

当连接中档 ARM64 真机后，应用相同 harness 重跑并保存新 JSON。只有 `profileMode`、
`realArm64Device` 和全部帧时目标同时成立时，才能标记为认证通过。
