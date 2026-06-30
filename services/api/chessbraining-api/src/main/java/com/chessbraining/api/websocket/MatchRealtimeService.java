package com.chessbraining.api.websocket;

import com.chessbraining.api.match.MatchResponse;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;

@Service
public class MatchRealtimeService {

	private final SimpMessagingTemplate messagingTemplate;

	public MatchRealtimeService(SimpMessagingTemplate messagingTemplate) {
		this.messagingTemplate = messagingTemplate;
	}

	public void publishMatchState(MatchResponse match) {
		messagingTemplate.convertAndSend(
				"/topic/matches/" + match.matchId(),
				new MatchEvent("match.state", match));
	}
}
