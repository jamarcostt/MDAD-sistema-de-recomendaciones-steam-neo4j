package com.matchplay.api.repository;

import com.matchplay.api.model.Game;
import org.springframework.data.neo4j.repository.Neo4jRepository;
import org.springframework.data.neo4j.repository.query.Query;
import java.util.List;

public interface GameRepository extends Neo4jRepository<Game, Long> {

    @Query("MATCH (g:Game) WHERE g.user_reviews IS NOT NULL " +
            "RETURN g ORDER BY g.user_reviews DESC SKIP $skip LIMIT $limit")
    List<Game> findTopByUserReviews(int skip, int limit);

    @Query("MATCH (g:Game) WHERE g.positive_ratio IS NOT NULL AND g.user_reviews >= 100 " +
            "RETURN g ORDER BY g.positive_ratio DESC SKIP $skip LIMIT $limit")
    List<Game> findTopByPositiveRatio(int skip, int limit);

    @Query("MATCH (g:Game)-[:HAS_TAG]->(t:Tag {name: $tagName}) " +
            "RETURN g ORDER BY g.user_reviews DESC SKIP $skip LIMIT $limit")
    List<Game> findByTag(String tagName, int skip, int limit);

    @Query("MATCH (g:Game) WHERE toLower(g.title) CONTAINS toLower($query) " +
            "RETURN g ORDER BY g.user_reviews DESC SKIP $skip LIMIT $limit")
    List<Game> searchByTitle(String query, int skip, int limit);
}