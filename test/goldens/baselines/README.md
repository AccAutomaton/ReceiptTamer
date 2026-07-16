# Golden 基线

此目录保存 19 张人工确认的 Flutter PNG：

- `home-*.png`：12 张首页，双视口 × 浅暗色 × 1.0/1.3/2.0 字号。
- `relief-shell-*.png`：4 张连续月账页、四栏导航与独立收件键主壳。
- `reimbursement-check-*.png`：3 张报销关联检查页代表状态。

使用下列命令更新对应分组：

```powershell
flutter test --update-goldens test/goldens/ledger_representative_golden_test.dart
flutter test --update-goldens test/goldens/relief_shell_component_golden_test.dart
flutter test --update-goldens test/goldens/reimbursement_check_golden_test.dart
```

更新前运行首页、账页与报销流程的 Widget 测试并人工检查差异；不要提交 `failures/`
临时图。
