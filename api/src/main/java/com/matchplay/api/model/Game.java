package com.matchplay.api.model;

import lombok.Data;
import org.springframework.data.neo4j.core.schema.*;
import java.util.List;

@Data
@Node("Game")
public class Game {

    @Id
    @Property("app_id")
    private Long appId;

    @Property("title")
    private String title;

    @Property("date_release")
    private String dateRelease;

    @Property("price_final")
    private Double price;

    @Property("positive_ratio")
    private Integer positiveRatio;

    @Property("user_reviews")
    private Integer userReviews;

    @Property("rating")
    private String rating;

    @Relationship(type = "HAS_TAG", direction = Relationship.Direction.OUTGOING)
    private List<Tag> tags;
}