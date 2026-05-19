package com.matchplay.api.model;

import lombok.Data;
import org.springframework.data.neo4j.core.schema.*;

@Data
@Node("Tag")
public class Tag {

    @Id
    @Property("name")
    private String name;
}