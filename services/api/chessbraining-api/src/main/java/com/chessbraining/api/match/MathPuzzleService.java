package com.chessbraining.api.match;

import java.security.SecureRandom;
import java.util.ArrayList;
import java.util.List;

import org.springframework.stereotype.Service;

@Service
public class MathPuzzleService {

	private static final int PUZZLE_COUNT = 10;
	private static final SecureRandom RANDOM = new SecureRandom();

	public record Puzzle(String expression, int answer) {}

	public record PuzzleSet(List<String> expressions, List<Integer> answers) {}

	public PuzzleSet generatePuzzles() {
		List<String> expressions = new ArrayList<>();
		List<Integer> answers = new ArrayList<>();

		for (int i = 0; i < PUZZLE_COUNT; i++) {
			Puzzle puzzle = generateSinglePuzzle();
			expressions.add(puzzle.expression());
			answers.add(puzzle.answer());
		}

		return new PuzzleSet(expressions, answers);
	}

	public boolean validateAnswer(List<Integer> correctAnswers, int questionIndex, int submittedAnswer) {
		if (questionIndex < 0 || questionIndex >= correctAnswers.size()) {
			return false;
		}
		return correctAnswers.get(questionIndex) == submittedAnswer;
	}

	private Puzzle generateSinglePuzzle() {
		int type = RANDOM.nextInt(3);

		return switch (type) {
			case 0 -> generateAddition();
			case 1 -> generateSubtraction();
			default -> generateMultiplication();
		};
	}

	private Puzzle generateAddition() {
		int a = RANDOM.nextInt(50) + 1;
		int b = RANDOM.nextInt(50) + 1;
		return new Puzzle(a + " + " + b, a + b);
	}

	private Puzzle generateSubtraction() {
		int a = RANDOM.nextInt(50) + 10;
		int b = RANDOM.nextInt(Math.min(a, 50)) + 1;
		return new Puzzle(a + " - " + b, a - b);
	}

	private Puzzle generateMultiplication() {
		int a = RANDOM.nextInt(12) + 1;
		int b = RANDOM.nextInt(12) + 1;
		return new Puzzle(a + " x " + b, a * b);
	}
}
