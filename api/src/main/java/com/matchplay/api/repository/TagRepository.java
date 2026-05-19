package com.matchplay.api.repository;

import com.matchplay.api.model.Tag;
import org.springframework.data.neo4j.repository.Neo4jRepository;

public interface TagRepository extends Neo4jRepository<Tag, String> {
}