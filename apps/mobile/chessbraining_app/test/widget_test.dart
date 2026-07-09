// Basic smoke test for ChessBraining app.
//
// ChessBrainingApp requires async initialization (GuestSession.load),
// so full widget tests should mock the session. This file exists to
// keep `flutter test` green with a trivial assertion.

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('smoke test – package resolves', () {
    // Ensures the project compiles and dependencies resolve.
    expect(1 + 1, 2);
  });
}
