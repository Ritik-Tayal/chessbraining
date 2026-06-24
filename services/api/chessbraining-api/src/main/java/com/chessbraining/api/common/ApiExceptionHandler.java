package com.chessbraining.api.common;

import java.time.Instant;
import java.util.Map;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
public class ApiExceptionHandler {

	@ExceptionHandler(ApiException.class)
	ResponseEntity<Map<String, Object>> handleApiException(ApiException exception) {
		return ResponseEntity.status(exception.getStatus()).body(Map.of(
				"timestamp", Instant.now().toString(),
				"code", exception.getCode(),
				"message", exception.getMessage()));
	}

	@ExceptionHandler(MethodArgumentNotValidException.class)
	ResponseEntity<Map<String, Object>> handleValidation(MethodArgumentNotValidException exception) {
		return ResponseEntity.badRequest().body(Map.of(
				"timestamp", Instant.now().toString(),
				"code", "VALIDATION_ERROR",
				"message", "Request validation failed"));
	}
}
