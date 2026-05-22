package com.matchplay.api.model;

import lombok.Data;
import org.springframework.data.neo4j.core.schema.*;
import java.util.ArrayList;
import java.util.List;

@Data
@Node("AppUser")
public class AppUser {

    @Id
    private String id = "app_user_1";

    private String name = "MatchPlay User";

    @Relationship(type = "OWNS", direction = Relationship.Direction.OUTGOING)
    private List<Game> library = new ArrayList<>();
}