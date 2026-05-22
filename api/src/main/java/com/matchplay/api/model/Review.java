package com.matchplay.api.model;

import lombok.Data;
import org.springframework.data.neo4j.core.schema.*;

@Data
@Node("Review")
public class Review {

    @Id
    @GeneratedValue
    private Long id;

    @Property("review_id")
    private String reviewId;

    private Boolean isRecommended;
    private Double hours;
    private Double hoursAtReview;
    private String date;
    private Integer funny;
    private Integer helpful;

    @Relationship(type = "ABOUT", direction = Relationship.Direction.OUTGOING)
    private Game game;
}