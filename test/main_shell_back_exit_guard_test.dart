import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_tamer/presentation/widgets/main_shell.dart';

void main() {
  test('first BACK prompts and a second within the window exits', () {
    final guard = MainShellBackExitGuard();
    final start = DateTime(2026, 7, 17, 12);

    expect(guard.register(start), MainShellBackDecision.showPrompt);
    expect(
      guard.register(start.add(const Duration(milliseconds: 1500))),
      MainShellBackDecision.exit,
    );
  });

  test('BACK after the window is treated as a new first press', () {
    final guard = MainShellBackExitGuard();
    final start = DateTime(2026, 7, 17, 12);

    expect(guard.register(start), MainShellBackDecision.showPrompt);
    expect(
      guard.register(start.add(const Duration(milliseconds: 2001))),
      MainShellBackDecision.showPrompt,
    );
  });

  test('reset prevents a later single BACK from exiting', () {
    final guard = MainShellBackExitGuard();
    final start = DateTime(2026, 7, 17, 12);

    expect(guard.register(start), MainShellBackDecision.showPrompt);
    guard.reset();

    expect(
      guard.register(start.add(const Duration(seconds: 1))),
      MainShellBackDecision.showPrompt,
    );
  });
}
