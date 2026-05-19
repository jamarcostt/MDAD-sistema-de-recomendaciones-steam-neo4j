package com.matchplay.api.service;

import lombok.RequiredArgsConstructor;
import org.springframework.data.neo4j.core.Neo4jClient;
import org.springframework.stereotype.Service;
import java.util.Collection;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class TagService {

    private final Neo4jClient neo4jClient;

    public Collection<Map<String, Object>> getTopTags(int limit) {
        return neo4jClient.query(
                "MATCH (g:Game)-[:HAS_TAG]->(t:Tag) " +
                        "RETURN t.name AS tag, count(g) AS total " +
                        "ORDER BY total DESC LIMIT $limit")
                .bind(limit).to("limit").fetch().all();
    }
}