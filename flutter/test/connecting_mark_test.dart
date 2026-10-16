import 'package:flutter/material.dart';
import 'package:flutter_hbb/common/widgets/s_mark.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isConnectingLabel', () {
    test('matches the English key and a translation', () {
      expect(isConnectingLabel('Connecting...', 'Conectando...'), isTrue);
      expect(isConnectingLabel('Conectando...', 'Conectando...'), isTrue);
    });

    test('leaves other loading labels alone', () {
      expect(isConnectingLabel('Waiting', 'Conectando...'), isFalse);
      expect(isConnectingLabel('Logging in...', 'Connecting...'), isFalse);
      expect(isConnectingLabel('', ''), isFalse);
    });
  });

  group('connectingDashWindow', () {
    test('slides the curve on, then off', () {
      final start = connectingDashWindow(0);
      expect(start.isEmpty, isTrue);

      final quarter = connectingDashWindow(0.25);
      expect(quarter.start, 0);
      expect(quarter.end, 0.5);

      final full = connectingDashWindow(0.5);
      expect(full.start, 0);
      expect(full.end, 1);
      expect(full.isEmpty, isFalse);

      final three = connectingDashWindow(0.75);
      expect(three.start, 0.5);
      expect(three.end, 1);

      final end = connectingDashWindow(1);
      expect(end.isEmpty, isTrue);
    });
  });

  ConnectingMarkPainter markPainter(WidgetTester tester) {
    final paints = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
    return paints
        .map((paint) => paint.painter)
        .whereType<ConnectingMarkPainter>()
        .single;
  }

  testWidgets('ConnectingMark paints and keeps looping', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: ConnectingMark())),
    ));
    expect(markPainter(tester).draw, 0);
    await tester.pump(const Duration(milliseconds: 700));
    expect(markPainter(tester).draw, greaterThan(0));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: Scaffold(body: ConnectingMark()),
      ),
    ));
    final still = markPainter(tester);
    expect(still.draw, 0.5);
    expect(still.pulse, 0.25);
    expect(tester.takeException(), isNull);
  });
}
