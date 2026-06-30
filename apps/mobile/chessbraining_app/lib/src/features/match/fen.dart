Map<String, String> parseFenBoard(String fen) {
  final board = <String, String>{};
  final placement = fen.split(' ').first;
  final ranks = placement.split('/');
  for (var rankIndex = 0; rankIndex < ranks.length; rankIndex++) {
    final rank = 8 - rankIndex;
    var fileIndex = 0;
    for (final unit in ranks[rankIndex].split('')) {
      final emptyCount = int.tryParse(unit);
      if (emptyCount != null) {
        fileIndex += emptyCount;
        continue;
      }
      final file = String.fromCharCode('a'.codeUnitAt(0) + fileIndex);
      board['$file$rank'] = unit;
      fileIndex++;
    }
  }
  return board;
}

String pieceLabel(String piece) {
  return switch (piece.toLowerCase()) {
    'k' => 'K',
    'q' => 'Q',
    'r' => 'R',
    'b' => 'B',
    'n' => 'N',
    'p' => 'P',
    _ => '',
  };
}

bool isWhitePiece(String piece) {
  return piece.toUpperCase() == piece;
}
