package com.chessbraining.api.match;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/brain-matches")
public class BrainMatchController {

	private final BrainMatchService service;

	public BrainMatchController(BrainMatchService service) {
		this.service = service;
	}

	@PostMapping
	public BrainMatchResponse create(@RequestBody(required = false) CreateBrainMatchRequest request) {
		return service.create(request);
	}

	@PostMapping("/join")
	public BrainMatchResponse join(@RequestBody JoinBrainMatchRequest request) {
		return service.join(request);
	}

	@GetMapping("/{matchId}")
	public BrainMatchResponse get(@PathVariable String matchId) {
		return service.get(matchId);
	}

	@PostMapping("/{matchId}/math-submissions")
	public BrainMatchResponse submitMath(@PathVariable String matchId, @RequestBody SubmitAnswerBatchRequest request) {
		return service.submitMath(matchId, request);
	}

	@PostMapping("/{matchId}/paths")
	public BrainMatchResponse submitPath(@PathVariable String matchId, @RequestBody SubmitPathRequest request) {
		return service.submitPath(matchId, request);
	}

	@PostMapping("/{matchId}/memory-turns")
	public BrainMatchResponse submitMemoryTurn(@PathVariable String matchId, @RequestBody SubmitMemoryTurnRequest request) {
		return service.submitMemoryTurn(matchId, request);
	}

	@PostMapping("/{matchId}/complete")
	public BrainMatchResponse complete(@PathVariable String matchId) {
		return service.complete(matchId);
	}

	@PostMapping("/{matchId}/rematch")
	public BrainMatchResponse rematch(@PathVariable String matchId, @RequestBody RematchRequest request) {
		return service.rematch(matchId, request);
	}
}
