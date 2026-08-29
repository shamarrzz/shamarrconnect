/// Same breakpoints on Windows, macOS, Linux, and Android (phones 1, tablets 2, wide 3).
int deskColumnCount(double width) {
  if (width < 640) return 1;
  if (width < 1000) return 2;
  return 3;
}

/// Shortest-column packing for the desk grid.
/// Ties go to the leftmost column so compact cards fill holes under tall ones.
List<List<int>> packShortestColumn({
  required int cols,
  required List<double> heights,
}) {
  final n = cols < 1 ? 1 : cols;
  final columns = List.generate(n, (_) => <int>[]);
  if (heights.isEmpty) return columns;
  final colH = List<double>.filled(n, 0);
  for (var i = 0; i < heights.length; i++) {
    var best = 0;
    for (var c = 1; c < n; c++) {
      if (colH[c] < colH[best]) best = c;
    }
    columns[best].add(i);
    colH[best] += heights[i];
  }
  return columns;
}

/// Relative height of a desk card. Stills are 16:10 of the card width.
double deskCardHeight({required bool hasStill, required double cardWidth}) {
  const body = 120.0;
  if (!hasStill) return body;
  return body + cardWidth * 10 / 16;
}
