package com.matchplay.api.service;

import com.matchplay.api.model.AppUser;
import com.matchplay.api.model.Game;
import com.matchplay.api.repository.AppUserRepository;
import com.matchplay.api.repository.GameRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.neo4j.core.Neo4jClient;
import org.springframework.stereotype.Service;

import java.util.Collection;
import java.util.Map;
import java.util.Optional;

@Service
@RequiredArgsConstructor
public class AppUserService {

        private final AppUserRepository appUserRepository;
        private final GameRepository gameRepository;
        private final Neo4jClient neo4jClient;

        private static final String USER_ID = "app_user_1";

        // ── Biblioteca ────────────────────────────────────────────

        public AppUser getUser() {
                return appUserRepository.findById(USER_ID)
                                .orElseGet(this::createUser);
        }

        private AppUser createUser() {
                AppUser user = new AppUser();
                return appUserRepository.save(user);
        }

        public AppUser addGameToLibrary(Long appId) {
                // Verificar que el juego existe
                gameRepository.findById(appId)
                                .orElseThrow(() -> new RuntimeException("Juego no encontrado: " + appId));

                // Crear la relación OWNS directamente sin tocar el nodo Game
                neo4jClient.query(
                                "MATCH (u:AppUser {id: $userId}), (g:Game {app_id: $appId}) " +
                                                "MERGE (u)-[:OWNS]->(g)")
                                .bind(USER_ID).to("userId").bind(appId).to("appId").run();

                return getUser();
        }

        public AppUser removeGameFromLibrary(Long appId) {
                neo4jClient.query(
                                "MATCH (u:AppUser {id: $userId})-[r:OWNS]->(g:Game {app_id: $appId}) " +
                                                "DELETE r")
                                .bind(USER_ID).to("userId").bind(appId).to("appId").run();

                return getUser();
        }

        // ── Análisis del usuario ──────────────────────────────────

        public Collection<Map<String, Object>> getUserTagDistribution() {
                return neo4jClient.query(
                                "MATCH (u:AppUser {id: $userId})-[:OWNS]->(g:Game)-[:HAS_TAG]->(t:Tag) " +
                                                "RETURN t.name AS tag, count(g) AS total " +
                                                "ORDER BY total DESC")
                                .bind(USER_ID).to("userId").fetch().all();
        }

        public Collection<Map<String, Object>> getPriceComparison() {
                return neo4jClient.query(
                                "MATCH (globalGame:Game) WHERE globalGame.price_final IS NOT NULL " +
                                                "WITH avg(globalGame.price_final) AS globalAvg " +
                                                "OPTIONAL MATCH (u:AppUser {id: $userId})-[:OWNS]->(g:Game) WHERE g.price_final IS NOT NULL "
                                                +
                                                "WITH globalAvg, avg(g.price_final) AS userAvg " +
                                                "RETURN coalesce(userAvg, 0) AS userAvg, globalAvg")
                                .bind(USER_ID).to("userId").fetch().all();
        }

        public Collection<Map<String, Object>> getPositiveRatioComparison() {
                return neo4jClient.query(
                                "MATCH (globalGame:Game) WHERE globalGame.positive_ratio IS NOT NULL " +
                                                "WITH avg(globalGame.positive_ratio) AS globalAvg " +
                                                "OPTIONAL MATCH (u:AppUser {id: $userId})-[:OWNS]->(g:Game) WHERE g.positive_ratio IS NOT NULL "
                                                +
                                                "WITH globalAvg, avg(g.positive_ratio) AS userAvg " +
                                                "RETURN coalesce(userAvg, 0) AS userAvg, globalAvg")
                                .bind(USER_ID).to("userId").fetch().all();
        }

        public Collection<Map<String, Object>> getMissingTags(int limit) {
                return neo4jClient.query(
                                "MATCH (g:Game)-[:HAS_TAG]->(t:Tag) " +
                                                "WHERE NOT ((:AppUser {id: $userId})-[:OWNS]->(:Game)-[:HAS_TAG]->(t)) "
                                                +
                                                "RETURN t.name AS tag, count(g) AS total " +
                                                "ORDER BY total DESC LIMIT $limit")
                                .bind(USER_ID).to("userId").bind(limit).to("limit").fetch().all();
        }

        // ── Recomendaciones ───────────────────────────────────────

        public Collection<Map<String, Object>> getContentBasedRecommendations(int limit) {
                return neo4jClient.query(
                                "MATCH (u:AppUser {id: $userId})-[:OWNS]->(owned:Game)-[:HAS_TAG]->(t:Tag) " +
                                                "MATCH (rec:Game)-[:HAS_TAG]->(t) " +
                                                "WHERE NOT (u)-[:OWNS]->(rec) " +
                                                "RETURN rec.app_id AS appId, rec.title AS title, rec.rating AS rating, "
                                                +
                                                "rec.positive_ratio AS positiveRatio, rec.user_reviews AS userReviews, "
                                                +
                                                "rec.price_final AS price, count(t) AS coincidencias " +
                                                "ORDER BY coincidencias DESC LIMIT $limit")
                                .bind(USER_ID).to("userId").bind(limit).to("limit").fetch().all();
        }

        public Collection<Map<String, Object>> getCollaborativeRecommendations(int limit) {
                return neo4jClient.query(
                                "MATCH (u:AppUser {id: $userId})-[:OWNS]->(g:Game) " +
                                                "<-[:ABOUT]-(:Review)<-[:WROTE]-(similar:User)-[:WROTE]->(:Review)-[:ABOUT]->(rec:Game) "
                                                +
                                                "WHERE NOT (u)-[:OWNS]->(rec) " +
                                                "RETURN rec.app_id AS appId, rec.title AS title, rec.rating AS rating, "
                                                +
                                                "rec.positive_ratio AS positiveRatio, rec.user_reviews AS userReviews, "
                                                +
                                                "rec.price_final AS price, count(similar) AS popularidad " +
                                                "ORDER BY popularidad DESC LIMIT $limit")
                                .bind(USER_ID).to("userId").bind(limit).to("limit").fetch().all();
        }

        public Collection<Map<String, Object>> getHybridRecommendations(int limit) {
                return neo4jClient.query(
                                "MATCH (u:AppUser {id: $userId})-[:OWNS]->(owned:Game)-[:HAS_TAG]->(t:Tag) " +
                                                "MATCH (rec:Game)-[:HAS_TAG]->(t) " +
                                                "WHERE NOT (u)-[:OWNS]->(rec) " +
                                                "WITH u, rec, count(t) AS tagScore " +
                                                "ORDER BY tagScore DESC LIMIT 500 " +
                                                "OPTIONAL MATCH (rec)<-[:ABOUT]-(:Review)<-[:WROTE]-(similar:User)-[:WROTE]->(:Review)-[:ABOUT]->(owned2:Game) "
                                                +
                                                "WHERE (u)-[:OWNS]->(owned2) " +
                                                "WITH rec, tagScore, count(similar) AS collabScore " +
                                                "RETURN rec.app_id AS appId, rec.title AS title, rec.rating AS rating, "
                                                +
                                                "rec.positive_ratio AS positiveRatio, rec.user_reviews AS userReviews, "
                                                +
                                                "rec.price_final AS price, (tagScore * 2 + collabScore) AS hybridScore "
                                                +
                                                "ORDER BY hybridScore DESC LIMIT $limit")
                                .bind(USER_ID).to("userId").bind(limit).to("limit").fetch().all();
        }

        // ── Grafos para D3 ────────────────────────────────────────

        public Collection<Map<String, Object>> getSimilarGamesGraph() {
                return neo4jClient.query(
                                "MATCH (u:AppUser {id: $userId})-[:OWNS]->(g:Game)-[:HAS_TAG]->(t:Tag) " +
                                                "MATCH (similar:Game)-[:HAS_TAG]->(t) " +
                                                "WHERE NOT (u)-[:OWNS]->(similar) AND similar <> g " +
                                                "WITH g, similar, count(t) AS shared " +
                                                "WHERE shared >= 3 " +
                                                "RETURN g.app_id AS sourceId, g.title AS sourceTitle, " +
                                                "similar.app_id AS targetId, similar.title AS targetTitle, shared " +
                                                "LIMIT 100")
                                .bind(USER_ID).to("userId").fetch().all();
        }

        public Collection<Map<String, Object>> getRelatedTagsGraph() {
                return neo4jClient.query(
                                "MATCH (u:AppUser {id: $userId})-[:OWNS]->(g:Game)-[:HAS_TAG]->(t1:Tag) " +
                                                "MATCH (g)-[:HAS_TAG]->(t2:Tag) " +
                                                "WHERE t1 <> t2 " +
                                                "RETURN t1.name AS source, t2.name AS target, count(g) AS weight " +
                                                "ORDER BY weight DESC LIMIT 80")
                                .bind(USER_ID).to("userId").fetch().all();
        }
}