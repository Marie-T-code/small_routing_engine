-- 006_create_table_graph_coverage.sql
-- Purpose: Stores graph coverage bounding box

CREATE TABLE graph_coverage (
    id SERIAL PRIMARY KEY,
    bbox geometry(POLYGON,4326)
);