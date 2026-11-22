package com.chessbraining.api.match;

import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;
import com.chessbraining.api.websocket.MatchRealtimeService;

@RestController
public class PieceSwitchController {
    private final BrainMatchService arena;
    private final BrainRoundService rounds;
    private final MatchService matches;
    private final MatchRealtimeService realtime;
    private final SimpMessagingTemplate messaging;
    private final BotService bots;

    public PieceSwitchController(BrainMatchService arena, BrainRoundService rounds, MatchService matches,
                                 MatchRealtimeService realtime, SimpMessagingTemplate messaging, BotService bots) {
        this.arena = arena;
        this.rounds = rounds;
        this.matches = matches;
        this.realtime = realtime;
        this.messaging = messaging;
        this.bots = bots;
    }
    @PostMapping("/api/v1/brain-matches/{id}/piece-switch/{action:ready|events}")
    public BrainMatchResponse arena(@PathVariable String id, @PathVariable String action, @RequestBody PieceSwitchEngine.Submission request) {
        long receivedAt = System.currentTimeMillis();
        var response = arena.pieceSwitch(id, request, "ready".equals(action)).progress(receivedAt);
        messaging.convertAndSend("/topic/piece-switch/" + id, response);
        return response;
    }
    @PostMapping("/api/v1/matches/{id}/brain-rounds/current/piece-switch/{action:ready|events}")
    public BrainRoundResponse chess(@PathVariable String id, @PathVariable String action, @RequestBody PieceSwitchEngine.Submission request) {
        long receivedAt = System.currentTimeMillis();
        var response = rounds.pieceSwitch(id, request, "ready".equals(action)).progress(receivedAt);
        messaging.convertAndSend("/topic/piece-switch/" + response.roundId(), response);
        var match = matches.getMatch(id);
        if (match.phase() != MatchPhase.BRAIN_ROUND) realtime.publishMatchState(match);
        bots.scheduleContinuation(id);
        return response;
    }
}
