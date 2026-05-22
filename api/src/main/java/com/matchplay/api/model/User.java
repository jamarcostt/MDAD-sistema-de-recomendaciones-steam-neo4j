package com.matchplay.api.model;

import lombok.Data;
import org.springframework.data.neo4j.core.schema.*;
import java.util.List;

@Data
@Node("User")
public class User {

    @Id
    @Property("user_id")
    private Long userId;

    private Integer products;
    private Integer reviews;

    @Relationship(type = "WROTE", direction = Relationship.Direction.OUTGOING)
    private List<Review> wrote;
}