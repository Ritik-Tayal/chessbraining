package com.chessbraining.api.match;

import java.security.SecureRandom;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import com.chessbraining.api.common.ApiException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

@Service
public class DotConnectPuzzleService {

	private static final int GRID_SIZE = 5;
	private static final int MIN_PATH_LENGTH = 8;
	private static final int MAX_PATH_LENGTH = 12;
	private static final int MIN_DOTS = 4;
	private static final int MAX_DOTS = 5;
	private static final SecureRandom RANDOM = new SecureRandom();

	private static final int[] DR = {-1, 1, 0, 0};
	private static final int[] DC = {0, 0, -1, 1};

	public record Dot(int row, int col) {}

	public record PuzzleData(int rows, int cols, List<Dot> dots, List<Dot> solutionPath) {}

	public record PuzzleSet(List<String> puzzles, List<Integer> answers) {}

	public PuzzleSet generatePuzzleSet(int puzzleCount) {
		List<String> puzzles = new ArrayList<>();
		List<Integer> answers = new ArrayList<>();
		tools.jackson.databind.ObjectMapper mapper = new tools.jackson.databind.ObjectMapper();

		for (int i = 0; i < puzzleCount; i++) {
			PuzzleData puzzle = generatePuzzle();
			try {
				puzzles.add(mapper.writeValueAsString(puzzle));
			} catch (tools.jackson.core.JacksonException e) {
				throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR,
						"PUZZLE_SERIALIZE_ERROR", "Failed to serialize dot-connect puzzle.");
			}
			answers.add(0);
		}

		return new PuzzleSet(puzzles, answers);
	}

	public boolean validatePath(String puzzleJson, List<List<Integer>> submittedPath) {
		if (submittedPath == null || submittedPath.size() < 2) {
			return false;
		}

		PuzzleData puzzle;
		try {
			puzzle = new tools.jackson.databind.ObjectMapper().readValue(puzzleJson, PuzzleData.class);
		} catch (tools.jackson.core.JacksonException e) {
			return false;
		}

		List<Dot> submittedCells = new ArrayList<>();
		for (List<Integer> coord : submittedPath) {
			if (coord == null || coord.size() != 2) {
				return false;
			}
			submittedCells.add(new Dot(coord.get(0), coord.get(1)));
		}

		return isContinuous(submittedCells)
				&& !hasSelfIntersection(submittedCells)
				&& staysWithinBounds(submittedCells, puzzle.rows(), puzzle.cols())
				&& visitsAllDots(submittedCells, puzzle.dots());
	}

	private PuzzleData generatePuzzle() {
		int targetLength = MIN_PATH_LENGTH + RANDOM.nextInt(MAX_PATH_LENGTH - MIN_PATH_LENGTH + 1);
		List<Dot> path = generateRandomPath(targetLength);

		if (path == null) {
			path = generateRandomPath(MIN_PATH_LENGTH);
		}
		if (path == null) {
			path = generateFallbackPath();
		}

		List<Dot> dots = selectDots(path);
		return new PuzzleData(GRID_SIZE, GRID_SIZE, dots, path);
	}

	private List<Dot> generateRandomPath(int targetLength) {
		for (int attempt = 0; attempt < 50; attempt++) {
			List<Dot> path = new ArrayList<>();
			boolean[][] visited = new boolean[GRID_SIZE][GRID_SIZE];

			int startRow = RANDOM.nextInt(GRID_SIZE);
			int startCol = RANDOM.nextInt(GRID_SIZE);

			if (buildPath(path, visited, startRow, startCol, targetLength)) {
				return path;
			}
		}
		return null;
	}

	private boolean buildPath(List<Dot> path, boolean[][] visited, int row, int col, int remaining) {
		path.add(new Dot(row, col));
		visited[row][col] = true;

		if (remaining == 1) {
			return true;
		}

		List<int[]> neighbors = new ArrayList<>();
		for (int idx = 0; idx < 4; idx++) {
			int nr = row + DR[idx];
			int nc = col + DC[idx];
			if (nr >= 0 && nr < GRID_SIZE && nc >= 0 && nc < GRID_SIZE && !visited[nr][nc]) {
				neighbors.add(new int[]{nr, nc});
			}
		}
		Collections.shuffle(neighbors, RANDOM);

		for (int[] neighbor : neighbors) {
			if (buildPath(path, visited, neighbor[0], neighbor[1], remaining - 1)) {
				return true;
			}
		}

		path.remove(path.size() - 1);
		visited[row][col] = false;
		return false;
	}

	private List<Dot> generateFallbackPath() {
		List<Dot> path = new ArrayList<>();
		int row = 0;
		int col = 0;
		for (int i = 0; i < GRID_SIZE; i++) {
			path.add(new Dot(row, col));
			if (col < GRID_SIZE - 1) {
				col++;
			} else {
				row++;
				col = 0;
			}
			if (row >= GRID_SIZE) break;
		}
		return path;
	}

	private List<Dot> selectDots(List<Dot> path) {
		int dotCount = MIN_DOTS + RANDOM.nextInt(MAX_DOTS - MIN_DOTS + 1);
		dotCount = Math.min(dotCount, path.size());

		Set<Integer> selectedIndices = new HashSet<>();
		selectedIndices.add(0);
		selectedIndices.add(path.size() - 1);

		int maxAttempts = 200;
		int attempts = 0;
		while (selectedIndices.size() < dotCount && attempts < maxAttempts) {
			attempts++;
			int idx = RANDOM.nextInt(path.size());
			if (selectedIndices.contains(idx)) {
				continue;
			}
			int minGap = Math.max(1, (path.size() - 2) / (dotCount - 1));
			boolean tooClose = false;
			for (int existing : selectedIndices) {
				if (Math.abs(idx - existing) < minGap) {
					tooClose = true;
					break;
				}
			}
			if (!tooClose) {
				selectedIndices.add(idx);
			}
		}

		List<Dot> dots = new ArrayList<>();
		List<Integer> sorted = new ArrayList<>(selectedIndices);
		sorted.sort(Integer::compareTo);
		for (int idx : sorted) {
			dots.add(path.get(idx));
		}
		return dots;
	}

	private boolean isContinuous(List<Dot> cells) {
		for (int i = 1; i < cells.size(); i++) {
			Dot prev = cells.get(i - 1);
			Dot curr = cells.get(i);
			int rowDiff = Math.abs(prev.row() - curr.row());
			int colDiff = Math.abs(prev.col() - curr.col());
			if (rowDiff + colDiff != 1) {
				return false;
			}
		}
		return true;
	}

	private boolean hasSelfIntersection(List<Dot> cells) {
		Set<String> seen = new HashSet<>();
		for (Dot cell : cells) {
			String key = cell.row() + "," + cell.col();
			if (!seen.add(key)) {
				return true;
			}
		}
		return false;
	}

	private boolean staysWithinBounds(List<Dot> cells, int rows, int cols) {
		for (Dot cell : cells) {
			if (cell.row() < 0 || cell.row() >= rows || cell.col() < 0 || cell.col() >= cols) {
				return false;
			}
		}
		return true;
	}

	private boolean visitsAllDots(List<Dot> path, List<Dot> requiredDots) {
		Set<String> pathCells = new HashSet<>();
		for (Dot cell : path) {
			pathCells.add(cell.row() + "," + cell.col());
		}
		for (Dot dot : requiredDots) {
			if (!pathCells.contains(dot.row() + "," + dot.col())) {
				return false;
			}
		}
		return true;
	}
}
