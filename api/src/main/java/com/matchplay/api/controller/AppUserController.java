package com.matchplay.api.controller;

import com.matchplay.api.model.AppUser;
import com.matchplay.api.service.AppUserService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Collection;
import java.util.Map;

@RestController
@RequestMapping("/api/user")
@RequiredArgsConstructor
public class AppUserController {

    private final AppUserService appUserService;

    // ── Biblioteca ────────────────────────────────────────────

    @GetMapping("/library")
    public ResponseEntity<AppUser> getLibrary() {
        return ResponseEntity.ok(appUserService.getUser());
    }

    @PostMapping("/library/{appId}")
    public ResponseEntity<AppUser> addGame(@PathVariable Long appId) {
        return ResponseEntity.ok(appUserService.addGameToLibrary(appId));
    }

    @DeleteMapping("/library/{appId}")
    public ResponseEntity<AppUser> removeGame(@PathVariable Long appId) {
        return ResponseEntity.ok(appUserService.removeGameFromLibrary(appId));
    }

    // ── Análisis ──────────────────────────────────────────────

    @GetMapping("/tag-distribution")
    public ResponseEntity<Collection<Map<String, Object>>> getTagDistribution() {
        return ResponseEntity.ok(appUserService.getUserTagDistribution());
    }

    @GetMapping("/price-comparison")
    public ResponseEntity<Collection<Map<String, Object>>> getPriceComparison() {
        return ResponseEntity.ok(appUserService.getPriceComparison());
    }

    @GetMapping("/ratio-comparison")
    public ResponseEntity<Collection<Map<String, Object>>> getRatioComparison() {
        return ResponseEntity.ok(appUserService.getPositiveRatioComparison());
    }

    @GetMapping("/missing-tags")
    public ResponseEntity<Collection<Map<String, Object>>> getMissingTags(
            @RequestParam(defaultValue = "0") int skip,
            @RequestParam(defaultValue = "10") int limit) {
        return ResponseEntity.ok(appUserService.getMissingTags(skip, limit));
    }

    @GetMapping("/recommendations/content")
    public ResponseEntity<Collection<Map<String, Object>>> getContentBased(
            @RequestParam(defaultValue = "0") int skip,
            @RequestParam(defaultValue = "20") int limit) {
        return ResponseEntity.ok(appUserService.getContentBasedRecommendations(skip, limit));
    }

    @GetMapping("/recommendations/collaborative")
    public ResponseEntity<Collection<Map<String, Object>>> getCollaborative(
            @RequestParam(defaultValue = "0") int skip,
            @RequestParam(defaultValue = "20") int limit) {
        return ResponseEntity.ok(appUserService.getCollaborativeRecommendations(skip, limit));
    }

    @GetMapping("/recommendations/hybrid")
    public ResponseEntity<Collection<Map<String, Object>>> getHybrid(
            @RequestParam(defaultValue = "0") int skip,
            @RequestParam(defaultValue = "20") int limit) {
        return ResponseEntity.ok(appUserService.getHybridRecommendations(skip, limit));
    }

    @GetMapping("/graph/similar-games")
    public ResponseEntity<Collection<Map<String, Object>>> getSimilarGamesGraph() {
        return ResponseEntity.ok(appUserService.getSimilarGamesGraph());
    }

    @GetMapping("/graph/related-tags")
    public ResponseEntity<Collection<Map<String, Object>>> getRelatedTagsGraph() {
        return ResponseEntity.ok(appUserService.getRelatedTagsGraph());
    }
}