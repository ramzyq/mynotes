import 'package:flutter_test/flutter_test.dart';
import 'package:mynotes/core/bootstrap/bootstrap_controller.dart';

void main() {
  test('sets ready when initialize succeeds', () async {
    final controller = BootstrapController(initialize: () async {});
    expect(controller.status, BootstrapStatus.initializing);
    await controller.bootstrap();
    expect(controller.status, BootstrapStatus.ready);
    expect(controller.errorMessage, isNull);
  });

  test('sets failed with message when initialize throws', () async {
    final controller = BootstrapController(
      initialize: () async => throw Exception('firebase down'),
    );
    await controller.bootstrap();
    expect(controller.status, BootstrapStatus.failed);
    expect(controller.errorMessage, contains('firebase down'));
  });

  test('retry recovers after a failure', () async {
    var attempts = 0;
    final controller = BootstrapController(
      initialize: () async {
        attempts++;
        if (attempts == 1) throw Exception('boom');
      },
    );
    await controller.bootstrap();
    expect(controller.status, BootstrapStatus.failed);
    await controller.bootstrap();
    expect(controller.status, BootstrapStatus.ready);
    expect(attempts, 2);
  });

  test('notifies listeners on state transitions', () async {
    final controller = BootstrapController(initialize: () async {});
    final seen = <BootstrapStatus>[];
    controller.addListener(() => seen.add(controller.status));
    await controller.bootstrap();
    expect(seen, contains(BootstrapStatus.ready));
  });
}
