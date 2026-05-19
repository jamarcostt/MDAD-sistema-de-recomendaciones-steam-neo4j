// =============================================================
//  init_graph.cypher
//  Carga completa del dataset Steam en Neo4j.
// =============================================================

// -- 1. INDICES Y CONSTRAINTS ---------------------------------
CREATE CONSTRAINT game_id IF NOT EXISTS
FOR (g:Game) REQUIRE g.app_id IS UNIQUE;

CREATE CONSTRAINT user_id IF NOT EXISTS
FOR (u:User) REQUIRE u.user_id IS UNIQUE;

CREATE CONSTRAINT tag_name IF NOT EXISTS
FOR (t:Tag) REQUIRE t.name IS UNIQUE;

CREATE INDEX review_idx IF NOT EXISTS
FOR (r:Review) ON (r.review_id);

// -- 2. JUEGOS ------------------------------------------------
LOAD CSV WITH HEADERS FROM 'file:///games_out.csv' AS row
MERGE (g:Game {app_id: toInteger(row.app_id)})
SET g.title          = row.title,
    g.date_release   = row.date_release,
    g.price_final          = toFloat(row.price_final),
    g.positive_ratio = toInteger(row.positive_ratio),
    g.user_reviews   = toInteger(row.user_reviews),
    g.rating         = row.rating;

// -- 3. TAGS Y RELACIONES CON JUEGOS -------------------------
LOAD CSV WITH HEADERS FROM 'file:///metadata_out.csv' AS row
MATCH (g:Game {app_id: toInteger(row.app_id)})
FOREACH (tag IN split(row.tags, '|') |
  MERGE (t:Tag {name: trim(tag)})
  MERGE (g)-[:HAS_TAG]->(t)
);

// -- 4. USUARIOS ---------------------------------------------
LOAD CSV WITH HEADERS FROM 'file:///users_out.csv' AS row
MERGE (u:User {user_id: toInteger(row.user_id)})
SET u.products = toInteger(row.products),
    u.reviews  = toInteger(row.reviews);

// -- 5. REVIEWS Y RELACIONES (carga en batches) -------------
LOAD CSV WITH HEADERS FROM 'file:///recommendations_out.csv' AS row
CALL {
  WITH row
  MATCH (u:User {user_id: toInteger(row.user_id)})
  MATCH (g:Game {app_id: toInteger(row.app_id)})
  MERGE (r:Review {review_id: row.review_id})
  SET r.is_recommended  = (row.is_recommended = 'true'),
      r.hours           = toFloat(row.hours),
      r.hours_at_review = toFloat(row.hours_at_review),
      r.date            = row.date,
      r.funny           = toInteger(row.funny),
      r.helpful         = toInteger(row.helpful)
  MERGE (u)-[:WROTE]->(r)
  MERGE (r)-[:ABOUT]->(g)
} IN TRANSACTIONS OF 10000 ROWS