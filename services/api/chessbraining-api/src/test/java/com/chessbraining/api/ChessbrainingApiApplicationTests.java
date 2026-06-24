package com.chessbraining.api;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.context.ActiveProfiles;

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

		mockMvc.perform(post("/api/v1/matches/{matchId}/brain-rounds/complete", matchId)
						.contentType(MediaType.APPLICATION_JSON)
						.content("""
								{
								  "winnerPlayerId": "white-player",
								  "whiteScore": 5,
								  "blackScore": 3
								}
								"""))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.phase").value("CHESS_PHASE"))
				.andExpect(jsonPath("$.white.brainPoints").value(2))
				.andExpect(jsonPath("$.black.brainPoints").value(0));
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
}
