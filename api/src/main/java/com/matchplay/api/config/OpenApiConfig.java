package com.matchplay.api.config;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class OpenApiConfig {

    @Bean
    public OpenAPI matchPlayOpenAPI() {
        return new OpenAPI()
                .info(new Info()
                        .title("MatchPlay API")
                        .description("API REST para el sistema de recomendaciones de videojuegos usando Neo4j.")
                        .version("v1.0"));
    }
}