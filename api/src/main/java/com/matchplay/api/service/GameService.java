package com.matchplay.api.service;

import com.matchplay.api.model.Game;
import com.matchplay.api.repository.GameRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.neo4j.core.Neo4jClient;
import org.springframework.stereotype.Service;
import java.util.Collection;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class GameService {

    private final GameRepository gameRepository;
    private final Neo4jClient neo4jClient;

    public List<Game> getTopByReviews(int skip, int limit) {
        return gameRepository.findTopByUserReviews(skip, limit);
    }

    public List<Game> getTopByPositiveRatio(int skip, int limit) {
        return gameRepository.findTopByPositiveRatio(skip, limit);
    }

    public Collection<Map<String, Object>> getPriceDistribution() {
        return neo4jClient.query(
                "MATCH (g:Game) WHERE g.price_final IS NOT NULL " +
                        "RETURN " +
                        "sum(CASE WHEN g.price_final = 0 THEN 1 ELSE 0 END) AS free, " +
                        "sum(CASE WHEN g.price_final > 0 AND g.price_final <= 5 THEN 1 ELSE 0 END) AS under5, " +
                        "sum(CASE WHEN g.price_final > 5 AND g.price_final <= 20 THEN 1 ELSE 0 END) AS under20, " +
                        "sum(CASE WHEN g.price_final > 20 THEN 1 ELSE 0 END) AS over20")
                .fetch().all();
    }

    public List<Game> getGamesByTag(String tagName, int skip, int limit) {
        return gameRepository.findByTag(tagName, skip, limit);
    }

    public List<Game> searchGames(String query, int skip, int limit) {
        if (query == null || query.trim().isEmpty()) {
            return List.of();
        }
        return gameRepository.searchByTitle(query.trim(), skip, limit);
    }
}