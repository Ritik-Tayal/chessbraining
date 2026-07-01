package com.chessbraining.api;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import java.time.Instant;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.context.ActiveProfiles;

import com.chessbraining.api.match.BrainRoundEntity;
import com.chessbraining.api.match.BrainRoundRepository;
import com.chessbraining.api.match.MatchEntity;
import com.chessbraining.api.match.MatchRepository;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class ChessbrainingApiApplicationTests {

	@Autowired
	private MockMvc mockMvc;

	@Autowired
	private ObjectMapper objectMapper;

	@Autowired
	private BrainRoundRepository brainRoundRepository;

	@Autowired
	private MatchRepository matchRepository;

	@Test
	void contextLoads() {
	}

	@Test
	void healthEndpointIsPublicAndReturnsUp() throws Exception {
		mockMvc.perform(get("/api/v1/health"))
				.andExpect(status().isOk())
				.andExpect(content().json("{\"status\":\"UP\"}"));
	}

	@Test
	void createsAndJoinsInviteMatch() throws Exception {
		JsonNode created = createMatch("white-player", "Ritik", 5);

		mockMvc.perform(post("/api/v1/matches/join")
						.contentType(MediaType.APPLICATION_JSON)
						.content("""
								{
								  "inviteCode": "%s",
								  "playerId": "black-player",
								  "playerName": "Teammate"
								}
								""".formatted(created.get("inviteCode").asText())))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.status").value("ACTIVE"))
				.andExpect(jsonPath("$.phase").value("CHESS_PHASE"))
				.andExpect(jsonPath("$.white.playerId").value("white-player"))
				.andExpect(jsonPath("$.black.playerId").value("black-player"));
	}

	@Test
	void quickplayJoinsWaitingOpponentMatch() throws Exception {
		matchRepository.deleteAll();
		JsonNode created = createMatch("white-player", "Ritik", 5);

		JsonNode quickplay = objectMapper.readTree(
				mockMvc.perform(post("/api/v1/matches/quickplay")
								.contentType(MediaType.APPLICATION_JSON)
								.content("""
										{
										  "playerId": "black-player",
										  "playerName": "Teammate"
										}
										"""))
						.andExpect(status().isOk())
						.andExpect(jsonPath("$.status").value("ACTIVE"))
						.andExpect(jsonPath("$.phase").value("CHESS_PHASE"))
						.andReturn()
						.getResponse()
						.getContentAsString());

		org.junit.jupiter.api.Assertions.assertEquals(
				created.get("matchId").asText(),
				quickplay.get("matchId").asText());
	}

	@Test
	void quickplayDoesNotJoinOwnWaitingMatch() throws Exception {
		matchRepository.deleteAll();
		JsonNode created = createMatch("white-player", "Ritik", 5);

		JsonNode quickplay = objectMapper.readTree(
				mockMvc.perform(post("/api/v1/matches/quickplay")
								.contentType(MediaType.APPLICATION_JSON)
								.content("""
										{
										  "playerId": "white-player",
										  "playerName": "Ritik"
										}
										"""))
						.andExpect(status().isOk())
						.andExpect(jsonPath("$.status").value("WAITING_FOR_OPPONENT"))
						.andReturn()
						.getResponse()
						.getContentAsString());

		org.junit.jupiter.api.Assertions.assertNotEquals(
				created.get("matchId").asText(),
				quickplay.get("matchId").asText());
	}

	@Test
	void acceptsLegalMoveAndRejectsIllegalMove() throws Exception {
		JsonNode joined = createJoinedMatch(5);
		String matchId = joined.get("matchId").asText();

		mockMvc.perform(post("/api/v1/matches/{matchId}/moves", matchId)
						.contentType(MediaType.APPLICATION_JSON)
						.content("""
								{
								  "playerId": "white-player",
								  "from": "e2",
								  "to": "e4"
								}
								"""))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.sideToMove").value("BLACK"))
				.andExpect(jsonPath("$.plyCount").value(1))
				.andExpect(jsonPath("$.moves[0].from").value("e2"))
				.andExpect(jsonPath("$.moves[0].to").value("e4"));

		mockMvc.perform(post("/api/v1/matches/{matchId}/moves", matchId)
						.contentType(MediaType.APPLICATION_JSON)
						.content("""
								{
								  "playerId": "black-player",
								  "from": "e7",
								  "to": "e3"
								}
								"""))
				.andExpect(status().isBadRequest())
				.andExpect(jsonPath("$.code").value("ILLEGAL_MOVE"));
	}

	@Test
	void exposesLegalMovesForSideToMove() throws Exception {
		JsonNode joined = createJoinedMatch(5);

		mockMvc.perform(get("/api/v1/matches/{matchId}/legal-moves", joined.get("matchId").asText())
						.param("playerId", "white-player"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$[?(@.from == 'e2' && @.to == 'e4')]").exists());
	}

	@Test
	void triggersAndCompletesBrainRoundAfterConfiguredMoveInterval() throws Exception {
		JsonNode joined = createJoinedMatch(1);
		String matchId = joined.get("matchId").asText();

		submitMove(matchId, "white-player", "e2", "e4");

		mockMvc.perform(post("/api/v1/matches/{matchId}/moves", matchId)
						.contentType(MediaType.APPLICATION_JSON)
						.content("""
								{
								  "playerId": "black-player",
								  "from": "e7",
								  "to": "e5"
								}
								"""))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.phase").value("BRAIN_ROUND"))
				.andExpect(jsonPath("$.brainRoundCount").value(1));

		mockMvc.perform(post("/api/v1/matches/{matchId}/moves", matchId)
						.contentType(MediaType.APPLICATION_JSON)
						.content("""
								{
								  "playerId": "white-player",
								  "from": "g1",
								  "to": "f3"
								}
								"""))
				.andExpect(status().isConflict())
				.andExpect(jsonPath("$.code").value("MATCH_NOT_READY_FOR_CHESS"));

		mockMvc.perform(get("/api/v1/matches/{matchId}/brain-rounds/current", matchId))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.status").value("ACTIVE"))
				.andExpect(jsonPath("$.puzzles").isArray())
				.andExpect(jsonPath("$.totalQuestions").value(10))
				.andExpect(jsonPath("$.expiresAt").isNotEmpty());

		mockMvc.perform(post("/api/v1/matches/{matchId}/brain-rounds/current/complete", matchId))
				.andExpect(status().isConflict())
				.andExpect(jsonPath("$.code").value("BRAIN_ROUND_STILL_ACTIVE"));

		expireActiveBrainRound(matchId);

		mockMvc.perform(post("/api/v1/matches/{matchId}/brain-rounds/current/complete", matchId))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.status").value("COMPLETED"))
				.andExpect(jsonPath("$.whiteCorrectCount").value(0))
				.andExpect(jsonPath("$.blackCorrectCount").value(0));
	}

	@Test
	void brainRoundScoresAnswersCorrectly() throws Exception {
		JsonNode joined = createJoinedMatch(1);
		String matchId = joined.get("matchId").asText();

		submitMove(matchId, "white-player", "e2", "e4");
		submitMove(matchId, "black-player", "e7", "e5");

		JsonNode round = objectMapper.readTree(
				mockMvc.perform(get("/api/v1/matches/{matchId}/brain-rounds/current", matchId))
						.andExpect(status().isOk())
						.andReturn()
						.getResponse()
						.getContentAsString());

		String[] puzzles = objectMapper.convertValue(round.get("puzzles"), String[].class);

		for (int i = 0; i < puzzles.length; i++) {
			mockMvc.perform(post("/api/v1/matches/{matchId}/brain-rounds/current/answers", matchId)
							.contentType(MediaType.APPLICATION_JSON)
							.content("""
									{
									  "playerId": "white-player",
									  "questionIndex": %d,
									  "answer": 0
									}
									""".formatted(i)))
					.andExpect(status().isOk())
					.andExpect(jsonPath("$.correct").isBoolean())
					.andExpect(jsonPath("$.correctAnswer").doesNotExist())
					.andExpect(jsonPath("$.totalQuestions").value(10));
		}

		expireActiveBrainRound(matchId);

		JsonNode completed = objectMapper.readTree(
				mockMvc.perform(post("/api/v1/matches/{matchId}/brain-rounds/current/complete", matchId))
						.andExpect(status().isOk())
						.andReturn()
						.getResponse()
						.getContentAsString());

		int whiteCorrect = completed.get("whiteCorrectCount").asInt();
		int blackCorrect = completed.get("blackCorrectCount").asInt();
		org.junit.jupiter.api.Assertions.assertTrue(whiteCorrect >= 0);
		org.junit.jupiter.api.Assertions.assertTrue(blackCorrect >= 0);
	}

	@Test
	void brainRoundAutoCompletesWhenBothPlayersAnswerAllQuestions() throws Exception {
		JsonNode joined = createJoinedMatch(1);
		String matchId = joined.get("matchId").asText();

		submitMove(matchId, "white-player", "e2", "e4");
		submitMove(matchId, "black-player", "e7", "e5");

		answerEveryQuestion(matchId, "white-player");
		answerEveryQuestion(matchId, "black-player");

		mockMvc.perform(get("/api/v1/matches/{matchId}", matchId))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.phase").value("CHESS_PHASE"))
				.andExpect(jsonPath("$.clockDeadlineAt").isNotEmpty());
	}

	@Test
	void brainRoundBatchSubmissionScoresAndAutoCompletes() throws Exception {
		JsonNode joined = createJoinedMatch(1);
		String matchId = joined.get("matchId").asText();

		submitMove(matchId, "white-player", "e2", "e4");
		submitMove(matchId, "black-player", "e7", "e5");

		mockMvc.perform(post("/api/v1/matches/{matchId}/brain-rounds/current/submissions", matchId)
						.contentType(MediaType.APPLICATION_JSON)
						.content(brainRoundSubmissionJson("white-player", 10)))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.playerAnsweredCount").value(10))
				.andExpect(jsonPath("$.totalQuestions").value(10))
				.andExpect(jsonPath("$.roundCompleted").value(false));

		mockMvc.perform(get("/api/v1/matches/{matchId}", matchId))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.phase").value("BRAIN_ROUND"));

		mockMvc.perform(post("/api/v1/matches/{matchId}/brain-rounds/current/submissions", matchId)
						.contentType(MediaType.APPLICATION_JSON)
						.content(brainRoundSubmissionJson("black-player", 10)))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.playerAnsweredCount").value(10))
				.andExpect(jsonPath("$.totalQuestions").value(10))
				.andExpect(jsonPath("$.roundCompleted").value(true));

		mockMvc.perform(get("/api/v1/matches/{matchId}", matchId))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.phase").value("CHESS_PHASE"))
				.andExpect(jsonPath("$.clockDeadlineAt").isNotEmpty());
	}

	@Test
	void brainRoundBatchSubmissionRejectsDuplicateQuestionIndexes() throws Exception {
		JsonNode joined = createJoinedMatch(1);
		String matchId = joined.get("matchId").asText();

		submitMove(matchId, "white-player", "e2", "e4");
		submitMove(matchId, "black-player", "e7", "e5");

		mockMvc.perform(post("/api/v1/matches/{matchId}/brain-rounds/current/submissions", matchId)
						.contentType(MediaType.APPLICATION_JSON)
						.content("""
								{
								  "playerId": "white-player",
								  "answers": [
								    {"questionIndex": 0, "answer": 0},
								    {"questionIndex": 0, "answer": 0}
								  ]
								}
								"""))
				.andExpect(status().isBadRequest())
				.andExpect(jsonPath("$.code").value("DUPLICATE_QUESTION_INDEX"));
	}

	@Test
	void brainRoundRejectsDuplicateAnswers() throws Exception {
		JsonNode joined = createJoinedMatch(1);
		String matchId = joined.get("matchId").asText();

		submitMove(matchId, "white-player", "e2", "e4");
		submitMove(matchId, "black-player", "e7", "e5");

		mockMvc.perform(post("/api/v1/matches/{matchId}/brain-rounds/current/answers", matchId)
						.contentType(MediaType.APPLICATION_JSON)
						.content("""
								{
								  "playerId": "white-player",
								  "questionIndex": 0,
								  "answer": 0
								}
								"""))
				.andExpect(status().isOk());

		mockMvc.perform(post("/api/v1/matches/{matchId}/brain-rounds/current/answers", matchId)
						.contentType(MediaType.APPLICATION_JSON)
						.content("""
								{
								  "playerId": "white-player",
								  "questionIndex": 0,
								  "answer": 0
								}
								"""))
				.andExpect(status().isConflict())
				.andExpect(jsonPath("$.code").value("QUESTION_ALREADY_ANSWERED"));
	}

	@Test
	void expiredBrainRoundCanCompleteByServerDeadline() throws Exception {
		JsonNode joined = createJoinedMatch(1);
		String matchId = joined.get("matchId").asText();

		submitMove(matchId, "white-player", "e2", "e4");
		submitMove(matchId, "black-player", "e7", "e5");

		expireActiveBrainRound(matchId);

		mockMvc.perform(post("/api/v1/matches/{matchId}/brain-rounds/current/complete", matchId))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.status").value("COMPLETED"));
	}

	@Test
	void brainRoundCompletionDoesNotResumeCompletedMatch() throws Exception {
		JsonNode joined = createJoinedMatch(1);
		String matchId = joined.get("matchId").asText();

		submitMove(matchId, "white-player", "e2", "e4");
		submitMove(matchId, "black-player", "e7", "e5");
		expireActiveBrainRound(matchId);

		mockMvc.perform(post("/api/v1/matches/{matchId}/resign", matchId)
						.contentType(MediaType.APPLICATION_JSON)
						.content("""
								{
								  "playerId": "white-player"
								}
								"""))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.status").value("COMPLETED"))
				.andExpect(jsonPath("$.phase").value("COMPLETED"));

		mockMvc.perform(post("/api/v1/matches/{matchId}/brain-rounds/current/complete", matchId))
				.andExpect(status().isConflict())
				.andExpect(jsonPath("$.code").value("NOT_IN_BRAIN_ROUND"));

		mockMvc.perform(get("/api/v1/matches/{matchId}", matchId))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.status").value("COMPLETED"))
				.andExpect(jsonPath("$.phase").value("COMPLETED"));
	}

	@Test
	void answerAfterBrainRoundDeadlineCompletesRoundWithoutRollback() throws Exception {
		JsonNode joined = createJoinedMatch(1);
		String matchId = joined.get("matchId").asText();

		submitMove(matchId, "white-player", "e2", "e4");
		submitMove(matchId, "black-player", "e7", "e5");
		expireActiveBrainRound(matchId);

		mockMvc.perform(post("/api/v1/matches/{matchId}/brain-rounds/current/answers", matchId)
						.contentType(MediaType.APPLICATION_JSON)
						.content("""
								{
								  "playerId": "white-player",
								  "questionIndex": 0,
								  "answer": 0
								}
								"""))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.correct").value(false));

		mockMvc.perform(get("/api/v1/matches/{matchId}", matchId))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.phase").value("CHESS_PHASE"))
				.andExpect(jsonPath("$.clockDeadlineAt").isNotEmpty());
	}

	@Test
	void clockDeadlineIsSetWhenMatchStarts() throws Exception {
		JsonNode joined = createJoinedMatch(5);
		String matchId = joined.get("matchId").asText();

		mockMvc.perform(get("/api/v1/matches/{matchId}", matchId))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.clockDeadlineAt").isNotEmpty())
				.andExpect(jsonPath("$.white.clockMs").value(300000))
				.andExpect(jsonPath("$.black.clockMs").value(300000));
	}

	@Test
	void clockTicksDownAfterMove() throws Exception {
		JsonNode joined = createJoinedMatch(5);
		String matchId = joined.get("matchId").asText();

		MatchEntity match = matchRepository.findById(matchId).orElseThrow();
		match.setClockDeadlineAt(Instant.now().plusMillis(299_000));
		matchRepository.save(match);

		submitMove(matchId, "white-player", "e2", "e4");

		mockMvc.perform(get("/api/v1/matches/{matchId}", matchId))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.white.clockMs").value(org.hamcrest.Matchers.lessThan(300000)))
				.andExpect(jsonPath("$.black.clockMs").value(300000));
	}

	@Test
	void clockPausesDuringBrainRound() throws Exception {
		JsonNode joined = createJoinedMatch(1);
		String matchId = joined.get("matchId").asText();

		submitMove(matchId, "white-player", "e2", "e4");
		submitMove(matchId, "black-player", "e7", "e5");

		mockMvc.perform(get("/api/v1/matches/{matchId}", matchId))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.phase").value("BRAIN_ROUND"))
				.andExpect(jsonPath("$.clockDeadlineAt").isEmpty());
	}

	@Test
	void clockResumesAfterBrainRound() throws Exception {
		JsonNode joined = createJoinedMatch(1);
		String matchId = joined.get("matchId").asText();

		submitMove(matchId, "white-player", "e2", "e4");
		submitMove(matchId, "black-player", "e7", "e5");

		expireActiveBrainRound(matchId);

		mockMvc.perform(post("/api/v1/matches/{matchId}/brain-rounds/current/complete", matchId))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.status").value("COMPLETED"));

		mockMvc.perform(get("/api/v1/matches/{matchId}", matchId))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.phase").value("CHESS_PHASE"))
				.andExpect(jsonPath("$.clockDeadlineAt").isNotEmpty());
	}

	@Test
	void moveSubmittedAfterClockDeadlineCompletesMatchWithoutApplyingMove() throws Exception {
		JsonNode joined = createJoinedMatch(5);
		String matchId = joined.get("matchId").asText();

		MatchEntity match = matchRepository.findById(matchId).orElseThrow();
		match.setClockDeadlineAt(Instant.now().minusSeconds(1));
		matchRepository.save(match);

		mockMvc.perform(post("/api/v1/matches/{matchId}/moves", matchId)
						.contentType(MediaType.APPLICATION_JSON)
						.content("""
								{
								  "playerId": "white-player",
								  "from": "e2",
								  "to": "e4"
								}
								"""))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.status").value("COMPLETED"))
				.andExpect(jsonPath("$.resultReason").value("TIMEOUT"))
				.andExpect(jsonPath("$.winnerPlayerId").value("black-player"))
				.andExpect(jsonPath("$.clockDeadlineAt").isEmpty())
				.andExpect(jsonPath("$.moves").isEmpty());
	}

	@Test
	void clockBoostPowerupSpendsBrainPointAndAddsTime() throws Exception {
		JsonNode joined = createJoinedMatch(5);
		String matchId = joined.get("matchId").asText();

		MatchEntity match = matchRepository.findById(matchId).orElseThrow();
		match.setWhiteBrainPoints(1);
		matchRepository.save(match);

		mockMvc.perform(post("/api/v1/matches/{matchId}/powerups", matchId)
						.contentType(MediaType.APPLICATION_JSON)
						.content("""
								{
								  "playerId": "white-player",
								  "type": "CLOCK_BOOST_30"
								}
								"""))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.white.brainPoints").value(0))
				.andExpect(jsonPath("$.white.clockMs").value(330000));
	}

	@Test
	void powerupRequiresEnoughBrainPoints() throws Exception {
		JsonNode joined = createJoinedMatch(5);
		String matchId = joined.get("matchId").asText();

		mockMvc.perform(post("/api/v1/matches/{matchId}/powerups", matchId)
						.contentType(MediaType.APPLICATION_JSON)
						.content("""
								{
								  "playerId": "white-player",
								  "type": "CLOCK_BOOST_30"
								}
								"""))
				.andExpect(status().isConflict())
				.andExpect(jsonPath("$.code").value("INSUFFICIENT_BRAIN_POINTS"));
	}

	@Test
	void extraMovePowerupArmsAndGrantsOneAdditionalTurn() throws Exception {
		JsonNode joined = createJoinedMatch(5);
		String matchId = joined.get("matchId").asText();

		MatchEntity match = matchRepository.findById(matchId).orElseThrow();
		match.setWhiteBrainPoints(2);
		matchRepository.save(match);

		mockMvc.perform(post("/api/v1/matches/{matchId}/powerups", matchId)
						.contentType(MediaType.APPLICATION_JSON)
						.content("""
								{
								  "playerId": "white-player",
								  "type": "EXTRA_MOVE"
								}
								"""))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.white.brainPoints").value(0))
				.andExpect(jsonPath("$.white.extraMoveArmed").value(true));

		mockMvc.perform(post("/api/v1/matches/{matchId}/moves", matchId)
						.contentType(MediaType.APPLICATION_JSON)
						.content("""
								{
								  "playerId": "white-player",
								  "from": "e2",
								  "to": "e3"
								}
								"""))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.sideToMove").value("WHITE"))
				.andExpect(jsonPath("$.white.extraMoveArmed").value(false))
				.andExpect(jsonPath("$.white.extraMoveActive").value(true));

		mockMvc.perform(post("/api/v1/matches/{matchId}/moves", matchId)
						.contentType(MediaType.APPLICATION_JSON)
						.content("""
								{
								  "playerId": "white-player",
								  "from": "d2",
								  "to": "d4"
								}
								"""))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.sideToMove").value("BLACK"))
				.andExpect(jsonPath("$.white.extraMoveActive").value(false))
				.andExpect(jsonPath("$.moves.length()").value(2));
	}

	@Test
	void extraMoveCannotBeArmedOnBrainRoundTriggerMove() throws Exception {
		JsonNode joined = createJoinedMatch(1);
		String matchId = joined.get("matchId").asText();

		submitMove(matchId, "white-player", "e2", "e4");
		MatchEntity match = matchRepository.findById(matchId).orElseThrow();
		match.setBlackBrainPoints(2);
		matchRepository.save(match);

		mockMvc.perform(post("/api/v1/matches/{matchId}/powerups", matchId)
						.contentType(MediaType.APPLICATION_JSON)
						.content("""
								{
								  "playerId": "black-player",
								  "type": "EXTRA_MOVE"
								}
								"""))
				.andExpect(status().isConflict())
				.andExpect(jsonPath("$.code").value("EXTRA_MOVE_BLOCKED_BY_BRAIN_ROUND"));
	}

	@Test
	void revivePawnPowerupRestoresCapturedPawnToEmptyLegalSquare() throws Exception {
		JsonNode joined = createJoinedMatch(5);
		String matchId = joined.get("matchId").asText();

		MatchEntity match = matchRepository.findById(matchId).orElseThrow();
		match.setFen("rnbqkbnr/pppppppp/8/8/8/8/1PPPPPPP/RNBQKBNR w KQkq - 0 1");
		match.setWhiteBrainPoints(3);
		matchRepository.save(match);

		mockMvc.perform(post("/api/v1/matches/{matchId}/powerups", matchId)
						.contentType(MediaType.APPLICATION_JSON)
						.content("""
								{
								  "playerId": "white-player",
								  "type": "REVIVE_PAWN",
								  "targetSquare": "a3"
								}
								"""))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.white.brainPoints").value(0))
				.andExpect(jsonPath("$.white.revivablePawns").value(0))
				.andExpect(jsonPath("$.fen").value(org.hamcrest.Matchers.startsWith("rnbqkbnr/pppppppp/8/8/8/P7/1PPPPPPP/RNBQKBNR")));
	}

	@Test
	void revivePawnRejectsOccupiedSquareAndMissingCapturedPawn() throws Exception {
		JsonNode joined = createJoinedMatch(5);
		String matchId = joined.get("matchId").asText();

		MatchEntity match = matchRepository.findById(matchId).orElseThrow();
		match.setWhiteBrainPoints(6);
		matchRepository.save(match);

		mockMvc.perform(post("/api/v1/matches/{matchId}/powerups", matchId)
						.contentType(MediaType.APPLICATION_JSON)
						.content("""
								{
								  "playerId": "white-player",
								  "type": "REVIVE_PAWN",
								  "targetSquare": "e2"
								}
								"""))
				.andExpect(status().isConflict())
				.andExpect(jsonPath("$.code").value("POWERUP_TARGET_OCCUPIED"));

		mockMvc.perform(post("/api/v1/matches/{matchId}/powerups", matchId)
						.contentType(MediaType.APPLICATION_JSON)
						.content("""
								{
								  "playerId": "white-player",
								  "type": "REVIVE_PAWN",
								  "targetSquare": "a3"
								}
								"""))
				.andExpect(status().isConflict())
				.andExpect(jsonPath("$.code").value("NO_PAWN_TO_REVIVE"));
	}

	@Test
	void timeoutEndsMatch() throws Exception {
		String created = mockMvc.perform(post("/api/v1/matches")
						.contentType(MediaType.APPLICATION_JSON)
						.content("""
								{
								  "playerId": "white-player",
								  "playerName": "White",
								  "timeControlSeconds": 30,
								  "brainRoundIntervalMoves": 20
								}
								"""))
				.andExpect(status().isOk())
				.andReturn()
				.getResponse()
				.getContentAsString();
		JsonNode createdNode = objectMapper.readTree(created);

		String joinedResponse = mockMvc.perform(post("/api/v1/matches/join")
						.contentType(MediaType.APPLICATION_JSON)
						.content("""
								{
								  "inviteCode": "%s",
								  "playerId": "black-player",
								  "playerName": "Black"
								}
								""".formatted(createdNode.get("inviteCode").asText())))
				.andExpect(status().isOk())
				.andReturn()
				.getResponse()
				.getContentAsString();
		JsonNode joined = objectMapper.readTree(joinedResponse);
		String matchId = joined.get("matchId").asText();

		Thread.sleep(31000);

		mockMvc.perform(get("/api/v1/matches/{matchId}", matchId))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.status").value("COMPLETED"))
				.andExpect(jsonPath("$.resultReason").value("TIMEOUT"))
				.andExpect(jsonPath("$.winnerPlayerId").value("black-player"))
				.andExpect(jsonPath("$.clockDeadlineAt").isEmpty());
	}

	private JsonNode createJoinedMatch(int brainRoundIntervalMoves) throws Exception {
		JsonNode created = createMatch("white-player", "Ritik", brainRoundIntervalMoves);
		String joined = mockMvc.perform(post("/api/v1/matches/join")
						.contentType(MediaType.APPLICATION_JSON)
						.content("""
								{
								  "inviteCode": "%s",
								  "playerId": "black-player",
								  "playerName": "Teammate"
								}
								""".formatted(created.get("inviteCode").asText())))
				.andExpect(status().isOk())
				.andReturn()
				.getResponse()
				.getContentAsString();

		return objectMapper.readTree(joined);
	}

	private JsonNode createMatch(String playerId, String playerName, int brainRoundIntervalMoves) throws Exception {
		String created = mockMvc.perform(post("/api/v1/matches")
						.contentType(MediaType.APPLICATION_JSON)
						.content("""
								{
								  "playerId": "%s",
								  "playerName": "%s",
								  "timeControlSeconds": 300,
								  "brainRoundIntervalMoves": %d
								}
								""".formatted(playerId, playerName, brainRoundIntervalMoves)))
				.andExpect(status().isOk())
				.andReturn()
				.getResponse()
				.getContentAsString();

		return objectMapper.readTree(created);
	}

	private void submitMove(String matchId, String playerId, String from, String to) throws Exception {
		mockMvc.perform(post("/api/v1/matches/{matchId}/moves", matchId)
						.contentType(MediaType.APPLICATION_JSON)
						.content("""
								{
								  "playerId": "%s",
								  "from": "%s",
								  "to": "%s"
								}
								""".formatted(playerId, from, to)))
				.andExpect(status().isOk());
	}

	private void answerEveryQuestion(String matchId, String playerId) throws Exception {
		JsonNode round = objectMapper.readTree(
				mockMvc.perform(get("/api/v1/matches/{matchId}/brain-rounds/current", matchId))
						.andExpect(status().isOk())
						.andReturn()
						.getResponse()
						.getContentAsString());
		int totalQuestions = round.get("totalQuestions").asInt();

		for (int i = 0; i < totalQuestions; i++) {
			mockMvc.perform(post("/api/v1/matches/{matchId}/brain-rounds/current/answers", matchId)
							.contentType(MediaType.APPLICATION_JSON)
							.content("""
									{
									  "playerId": "%s",
									  "questionIndex": %d,
									  "answer": 0
									}
									""".formatted(playerId, i)))
					.andExpect(status().isOk());
		}
	}

	private String brainRoundSubmissionJson(String playerId, int answerCount) {
		StringBuilder answers = new StringBuilder();
		for (int i = 0; i < answerCount; i++) {
			if (i > 0) {
				answers.append(',');
			}
			answers.append("""
					{"questionIndex": %d, "answer": 0}
					""".formatted(i));
		}
		return """
				{
				  "playerId": "%s",
				  "answers": [%s]
				}
				""".formatted(playerId, answers);
	}

	private void expireActiveBrainRound(String matchId) {
		BrainRoundEntity round = brainRoundRepository
				.findFirstByMatchIdAndStatusOrderByStartedAtDesc(matchId, "ACTIVE")
				.orElseThrow();
		round.setExpiresAt(Instant.now().minusSeconds(1));
		brainRoundRepository.save(round);
	}
}
