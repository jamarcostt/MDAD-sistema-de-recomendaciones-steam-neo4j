package com.matchplay.api.controller;

import com.matchplay.api.model.Game;
import com.matchplay.api.service.GameService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.Collection;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/games")
@RequiredArgsConstructor
public class GameController {

    private final GameService gameService;

    @GetMapping("/top-reviews")
    public ResponseEntity<List<Game>> getTopByReviews(
            @RequestParam(defaultValue = "0") int skip,
            @RequestParam(defaultValue = "20") int limit) {
        return ResponseEntity.ok(gameService.getTopByReviews(skip, limit));
    }

    @GetMapping("/top-rated")
    public ResponseEntity<List<Game>> getTopByPositiveRatio(
            @RequestParam(defaultValue = "0") int skip,
            @RequestParam(defaultValue = "20") int limit) {
        return ResponseEntity.ok(gameService.getTopByPositiveRatio(skip, limit));
    }

    @GetMapping("/price-distribution")
    public ResponseEntity<Collection<Map<String, Object>>> getPriceDistribution() {
        return ResponseEntity.ok(gameService.getPriceDistribution());
    }

    @GetMapping("/by-tag")
    public ResponseEntity<List<Game>> getByTag(
            @RequestParam String tagName,
            @RequestParam(defaultValue = "0") int skip,
            @RequestParam(defaultValue = "20") int limit) {
        return ResponseEntity.ok(gameService.getGamesByTag(tagName, skip, limit));
    }

    @GetMapping("/search")
    public ResponseEntity<List<Game>> searchGames(
            @RequestParam String q,
            @RequestParam(defaultValue = "0") int skip,
            @RequestParam(defaultValue = "20") int limit) {
        return ResponseEntity.ok(gameService.searchGames(q, skip, limit));
    }
}