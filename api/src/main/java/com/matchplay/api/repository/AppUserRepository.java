package com.matchplay.api.repository;

import com.matchplay.api.model.AppUser;
import org.springframework.data.neo4j.repository.Neo4jRepository;

public interface AppUserRepository extends Neo4jRepository<AppUser, String> {
}