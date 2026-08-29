import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/common/widgets/desk/desk_layout.dart';

void main() {
  group('packShortestColumn', () {
    test('fills the hole under a short card in 3 columns', () {
      // HERE (short), two stills, then a compact peer — compact goes under HERE.
      final heights = <double>[120, 320, 320, 120];
      final cols = packShortestColumn(cols: 3, heights: heights);
      expect(cols[0], [0, 3]);
      expect(cols[1], [1]);
      expect(cols[2], [2]);
    });

    test('fills the hole under a short card in 2 columns', () {
      final heights = <double>[120, 320, 120, 120];
      final cols = packShortestColumn(cols: 2, heights: heights);
      expect(cols[0], [0, 2, 3]);
      expect(cols[1], [1]);
    });

    test('ties go to the leftmost column', () {
      final cols = packShortestColumn(cols: 3, heights: [10, 10, 10]);
      expect(cols[0], [0]);
      expect(cols[1], [1]);
      expect(cols[2], [2]);
    });

    test('one column keeps order', () {
      final cols = packShortestColumn(cols: 1, heights: [1, 2, 3]);
      expect(cols, [
        [0, 1, 2]
      ]);
    });
  });

  group('deskColumnCount', () {
    test('phone and incoming-only widths stay one column', () {
      expect(deskColumnCount(320), 1);
      expect(deskColumnCount(639), 1);
    });

    test('tablet and two-pane desktop use two columns', () {
      expect(deskColumnCount(640), 2);
      expect(deskColumnCount(999), 2);
    });

    test('wide desk uses three columns on every OS', () {
      expect(deskColumnCount(1000), 3);
      expect(deskColumnCount(1600), 3);
    });
  });

  group('deskCardHeight', () {
    test('stills are taller than compact cards', () {
      final compact = deskCardHeight(hasStill: false, cardWidth: 320);
      final still = deskCardHeight(hasStill: true, cardWidth: 320);
      expect(still, greaterThan(compact + 100));
    });
  });
}
