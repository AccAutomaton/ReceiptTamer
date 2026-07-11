# ARM64 profile 帧时验收

`ledger_profile_test.dart` 使用 1,000 订单、500 发票、36 个月的脱敏内存仓库，驱动订单/
发票连续滚动、反向滚动、分支切换和月份快速滚动，并从 Flutter `FrameTiming`
计算 build/raster p90、p99 以及超过 16ms 的帧比例。被测页面保持 `ce04b3c` 的原始
内容和交互，不把尚未接入页面的 DAO 分页能力写成 UI 功能。SQLite 查询性能由
`test/performance/ledger_sqlite_performance_test.dart` 的同规模真实表夹具单独约束。

仅以下命令可生成认证结果：

```powershell
flutter drive --profile -d <ARM64_REAL_DEVICE_ID> `
  --driver=test_driver/integration_test.dart `
  --target=integration_test/ledger_profile_test.dart `
  --dart-define=LEDGER_PROFILE_RUN=true `
  --dart-define=LEDGER_PROFILE_CERTIFY=true
```

测试会用 Flutter 的 `kProfileMode` 验证真实构建模式，并结合 `device_info_plus` 的
`isPhysicalDevice` 与 Dart 进程的 `Abi.current()` 验证物理设备和实际 ARM64 进程；
调用方不能通过 `dart-define` 自报这些条件。报告同时记录 `processAbi` 和
`supportedAbis` 作为运行时证据。

如只想在模拟器验证流程和报告生成，使用同一 `flutter drive --profile` 命令，但只传
`LEDGER_PROFILE_RUN=true`。模拟器即使支持 ARM64 translation，也会因
`isPhysicalDevice == false` 明确标记 `certified: false`，不得用于宣称 ARM64 性能达标。
