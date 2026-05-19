package com.matchplay.api.controller;

import com.matchplay.api.service.TagService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Collection;
import java.util.Map;

@RestController
@RequestMapping("/api/tags")
@RequiredArgsConstructor
public class TagController {

    private final TagService tagService;

    @GetMapping("/top")
    public ResponseEntity<Collection<Map<String, Object>>> getTopTags(
            @RequestParam(defaultValue = "0") int skip,
            @RequestParam(defaultValue = "20") int limit) {
        return ResponseEntity.ok(tagService.getTopTags(skip, limit));
    }
}