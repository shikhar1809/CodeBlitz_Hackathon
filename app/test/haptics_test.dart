import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winger/core/feedback/haptics.dart';
import 'package:winger/core/feedback/pressable.dart';
import 'package:winger/core/widgets/big_choice_tile.dart';
import 'package:winger/features/onboarding/phone_screens.dart';

import 'support/fake_haptics.dart';
import 'support/golden_harness.dart';

void main() {
  test('each word maps to one kind, and the switch silences all of them', () {
    final fake = FakeHaptics.install();
    Haptics.tap();
    Haptics.confirm();
    Haptics.error();
    Haptics.alarm();
    expect(fake.calls, HapticKind.values);

    Haptics.enabled = false;
    Haptics.confirm();
    expect(fake.calls, hasLength(4), reason: 'off means silent');
  });

  test('Haptics.on keeps a disabled button disabled', () {
    final fake = FakeHaptics.install();
    expect(Haptics.on(null), isNull);
    var ran = false;
    Haptics.on(() => ran = true, HapticKind.confirm)!();
    expect(ran, isTrue);
    expect(fake.calls, [HapticKind.confirm]);
  });

  test('the real motor path never throws in a test', () {
    Haptics.tap();
    Haptics.error();
  });

  testWidgets('a tile taps once, and gives while pressed', (tester) async {
    final fake = FakeHaptics.install();
    var taps = 0;
    await tester.pumpWidget(
      themed(
        Scaffold(
          body: BigChoiceTile(title: 'Patient', onTap: () => taps++),
        ),
      ),
    );
    double scale() =>
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;
    expect(scale(), 1, reason: 'at rest nothing moves in a golden');

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Patient')),
    );
    await tester.pump();
    expect(scale(), .97);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(scale(), 1);
    expect(taps, 1);
    expect(fake.calls, [HapticKind.tap]);
  });

  testWidgets('a disabled tile neither gives nor buzzes', (tester) async {
    final fake = FakeHaptics.install();
    await tester.pumpWidget(
      themed(const Scaffold(body: BigChoiceTile(title: 'Patient'))),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Patient')),
    );
    await tester.pump();
    expect(tester.widget<Pressable>(find.byType(Pressable)).enabled, isFalse);
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    await gesture.up();
    expect(fake.calls, isEmpty);
  });

  testWidgets('a wrong OTP buzzes as an error, the right one confirms', (
    tester,
  ) async {
    final fake = FakeHaptics.install();
    usePhoneSurface(tester);
    var verified = false;
    await tester.pumpWidget(
      themed(OtpScreen(phone: '9876543210', onVerified: () => verified = true)),
    );
    await tester.enterText(find.byType(TextField), '0000');
    await tester.tap(find.text('Verify'));
    await tester.pump();
    expect(fake.calls, [HapticKind.error]);
    expect(verified, isFalse);

    await tester.enterText(find.byType(TextField), demoOtp);
    await tester.tap(find.text('Verify'));
    await tester.pump();
    expect(fake.calls, [HapticKind.error, HapticKind.confirm]);
    expect(verified, isTrue);
  });
}
