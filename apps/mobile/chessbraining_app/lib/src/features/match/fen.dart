const startingFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

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

String moveNotationFromFen({
  required String fenBefore,
  required String from,
  required String to,
  String? promotion,
}) {
  final board = parseFenBoard(fenBefore.isEmpty ? startingFen : fenBefore);
  final piece = board[from];
  if (piece == null) {
    return '$from-$to';
  }

  final pieceType = piece.toLowerCase();
  final fromFile = _fileIndex(from);
  final toFile = _fileIndex(to);
  final targetPiece = board[to];
  final isPawn = pieceType == 'p';
  final isCastle = pieceType == 'k' && (fromFile - toFile).abs() == 2;
  if (isCastle) {
    return toFile > fromFile ? 'O-O' : 'O-O-O';
  }

  final enPassant = _fenField(fenBefore, 3, '-');
  final isCapture =
      targetPiece != null || (isPawn && fromFile != toFile && to == enPassant);
  final promotionSuffix = _promotionSuffix(promotion);

  if (isPawn) {
    final capturePrefix = isCapture ? '${from[0]}x' : '';
    return '$capturePrefix$to$promotionSuffix';
  }

  final disambiguation = _disambiguation(board, piece, from, to);
  final captureMarker = isCapture ? 'x' : '';
  return '${pieceLabel(piece)}$disambiguation$captureMarker$to';
}

String applyMoveToFen({
  required String fen,
  required String from,
  required String to,
  String? promotion,
}) {
  final parts = fen.split(' ');
  final board = parseFenBoard(fen);
  final piece = board[from];
  if (piece == null) {
    return fen;
  }

  final sideToMove = parts.length > 1 ? parts[1] : 'w';
  final castling = parts.length > 2 ? parts[2] : '-';
  final enPassant = parts.length > 3 ? parts[3] : '-';
  final halfMove = parts.length > 4 ? int.tryParse(parts[4]) ?? 0 : 0;
  final fullMove = parts.length > 5 ? int.tryParse(parts[5]) ?? 1 : 1;
  final white = isWhitePiece(piece);
  final targetPiece = board[to];
  final movingPawn = piece.toLowerCase() == 'p';
  final fromFile = _fileIndex(from);
  final toFile = _fileIndex(to);
  final fromRank = _rank(from);
  final toRank = _rank(to);

  board.remove(from);

  if (movingPawn && to == enPassant && targetPiece == null) {
    final capturedRank = white ? toRank - 1 : toRank + 1;
    board.remove('${to[0]}$capturedRank');
  }

  if (piece.toLowerCase() == 'k' && (fromFile - toFile).abs() == 2) {
    if (toFile > fromFile) {
      final rookFrom = 'h$fromRank';
      final rookTo = 'f$fromRank';
      final rook = board.remove(rookFrom);
      if (rook != null) {
        board[rookTo] = rook;
      }
    } else {
      final rookFrom = 'a$fromRank';
      final rookTo = 'd$fromRank';
      final rook = board.remove(rookFrom);
      if (rook != null) {
        board[rookTo] = rook;
      }
    }
  }

  var placedPiece = piece;
  if (movingPawn && (toRank == 1 || toRank == 8)) {
    final promoted = (promotion == null || promotion.trim().isEmpty)
        ? 'q'
        : promotion.toLowerCase();
    placedPiece = white ? promoted.toUpperCase() : promoted;
  }
  board[to] = placedPiece;

  final nextSide = sideToMove == 'w' ? 'b' : 'w';
  final nextCastling = _updateCastlingRights(
    castling,
    piece: piece,
    from: from,
    capturedPiece: targetPiece,
    to: to,
  );
  final nextEnPassant = movingPawn && (fromRank - toRank).abs() == 2
      ? '${from[0]}${white ? fromRank + 1 : fromRank - 1}'
      : '-';
  final nextHalfMove = movingPawn || targetPiece != null ? 0 : halfMove + 1;
  final nextFullMove = sideToMove == 'b' ? fullMove + 1 : fullMove;

  return '${_boardToPlacement(board)} $nextSide $nextCastling $nextEnPassant $nextHalfMove $nextFullMove';
}

String _fenField(String fen, int index, String fallback) {
  final parts = fen.split(' ');
  return parts.length > index ? parts[index] : fallback;
}

String _promotionSuffix(String? promotion) {
  if (promotion == null || promotion.trim().isEmpty) {
    return '';
  }
  return '=${promotion.trim().toUpperCase()}';
}

String _disambiguation(
  Map<String, String> board,
  String piece,
  String from,
  String to,
) {
  final alternatives = board.entries
      .where((entry) =>
          entry.key != from &&
          entry.value.toLowerCase() == piece.toLowerCase() &&
          isWhitePiece(entry.value) == isWhitePiece(piece) &&
          _pieceCanReach(board, entry.value, entry.key, to))
      .map((entry) => entry.key)
      .toList();
  if (alternatives.isEmpty) {
    return '';
  }

  final sameFile = alternatives.any((square) => square[0] == from[0]);
  final sameRank =
      alternatives.any((square) => square.substring(1) == from.substring(1));
  if (!sameFile) {
    return from[0];
  }
  if (!sameRank) {
    return from.substring(1);
  }
  return from;
}

bool _pieceCanReach(
  Map<String, String> board,
  String piece,
  String from,
  String to,
) {
  final target = board[to];
  if (target != null && isWhitePiece(target) == isWhitePiece(piece)) {
    return false;
  }

  final fileDelta = _fileIndex(to) - _fileIndex(from);
  final rankDelta = _rank(to) - _rank(from);
  final absFileDelta = fileDelta.abs();
  final absRankDelta = rankDelta.abs();

  return switch (piece.toLowerCase()) {
    'n' => (absFileDelta == 1 && absRankDelta == 2) ||
        (absFileDelta == 2 && absRankDelta == 1),
    'b' => absFileDelta == absRankDelta && _pathClear(board, from, to),
    'r' => (fileDelta == 0 || rankDelta == 0) && _pathClear(board, from, to),
    'q' =>
      ((absFileDelta == absRankDelta) || (fileDelta == 0 || rankDelta == 0)) &&
          _pathClear(board, from, to),
    'k' => absFileDelta <= 1 && absRankDelta <= 1,
    _ => false,
  };
}

bool _pathClear(Map<String, String> board, String from, String to) {
  final fileStep = (_fileIndex(to) - _fileIndex(from)).sign;
  final rankStep = (_rank(to) - _rank(from)).sign;
  var file = _fileIndex(from) + fileStep;
  var rank = _rank(from) + rankStep;

  while (file != _fileIndex(to) || rank != _rank(to)) {
    final square = '${String.fromCharCode('a'.codeUnitAt(0) + file)}$rank';
    if (board.containsKey(square)) {
      return false;
    }
    file += fileStep;
    rank += rankStep;
  }
  return true;
}

String _boardToPlacement(Map<String, String> board) {
  final rows = <String>[];
  for (var rank = 8; rank >= 1; rank--) {
    final row = StringBuffer();
    var empty = 0;
    for (var fileIndex = 0; fileIndex < 8; fileIndex++) {
      final square =
          '${String.fromCharCode('a'.codeUnitAt(0) + fileIndex)}$rank';
      final piece = board[square];
      if (piece == null) {
        empty++;
        continue;
      }
      if (empty > 0) {
        row.write(empty);
        empty = 0;
      }
      row.write(piece);
    }
    if (empty > 0) {
      row.write(empty);
    }
    rows.add(row.toString());
  }
  return rows.join('/');
}

String _updateCastlingRights(
  String castling, {
  required String piece,
  required String from,
  required String? capturedPiece,
  required String to,
}) {
  if (castling == '-') {
    return '-';
  }
  final rights = castling.split('').toSet();
  switch (piece) {
    case 'K':
      rights
        ..remove('K')
        ..remove('Q');
    case 'k':
      rights
        ..remove('k')
        ..remove('q');
    case 'R':
      if (from == 'h1') rights.remove('K');
      if (from == 'a1') rights.remove('Q');
    case 'r':
      if (from == 'h8') rights.remove('k');
      if (from == 'a8') rights.remove('q');
  }
  if (capturedPiece == 'R') {
    if (to == 'h1') rights.remove('K');
    if (to == 'a1') rights.remove('Q');
  }
  if (capturedPiece == 'r') {
    if (to == 'h8') rights.remove('k');
    if (to == 'a8') rights.remove('q');
  }
  final ordered = ['K', 'Q', 'k', 'q'].where(rights.contains).join();
  return ordered.isEmpty ? '-' : ordered;
}

int _fileIndex(String square) => square.codeUnitAt(0) - 'a'.codeUnitAt(0);

int _rank(String square) => int.parse(square.substring(1));
