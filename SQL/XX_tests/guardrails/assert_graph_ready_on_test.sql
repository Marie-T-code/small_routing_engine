-- /SQL/XX_tests/guardrails/assert_graph_ready_on_test.sql

\echo ''
\echo '============================================================'
\echo 'TEST SUITE : assert_graph_ready_on()'
\echo '============================================================'
\echo ''

-----------------------------------------------------------------
-- TEST 1 : VIEWS_MISSING — edges view does not exist
-----------------------------------------------------------------

\echo 'TEST 1 : VIEWS_MISSING (edges)'

DO $$

BEGIN
    PERFORM assert_graph_ready_on(
        'pg_temp.fake_edges_view',
        'pg_temp.fake_vertices_view'
    );
    RAISE EXCEPTION  'Expected [GRAPH_STATE:VIEWS_MISSING], but no error was raised';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLERRM LIKE '%[GRAPH_STATE:VIEWS_MISSING]%' THEN
                RAISE NOTICE 'OK : expected error caught -> %', SQLERRM;
            ELSE
                RAISE EXCEPTION 'Unexpected error for TEST 1: %', SQLERRM;
            END IF;

END 
$$ LANGUAGE plpgsql;

-----------------------------------------------------------------
-- TEST 2 : VIEWS_MISSING — vertices view does not exist
-----------------------------------------------------------------

\echo 'TEST 2 : VIEWS_MISSING (vertices)'

DO $$

BEGIN
    PERFORM assert_graph_ready_on(
        'public.routing_edges', 
        'pg_temp.fake_vertices_view'
    );
    RAISE EXCEPTION 'Expected [GRAPH_STATE:VIEWS_MISSING], but no error was raised';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLERRM LIKE '%[GRAPH_STATE:VIEWS_MISSING]%' THEN
                RAISE NOTICE 'OK : expected error caught -> %', SQLERRM;
            ELSE
                RAISE EXCEPTION 'Unexpected error for TEST 2: %', SQLERRM;
            END IF;

END
$$ LANGUAGE plpgsql;

-------------------------------------------------------------------------------------
-- TEST 3 : CRITICAL_COLS_MISSING — critical column(s) on edges view exist(s) or not
-------------------------------------------------------------------------------------

\echo 'TEST 3: [GRAPH_STATE:CRITICAL_COLS_MISSING] on edges view'

DROP TABLE IF EXISTS edges_test CASCADE;

CREATE TEMP TABLE edges_test(
    source double precision, 
    cost double precision, 
    reverse_cost double precision, 
    geom geometry
);
CREATE VIEW pg_temp.v_edges_test AS
    SELECT * FROM pg_temp.edges_test;

DO $$

BEGIN
    PERFORM assert_graph_ready_on(
        'pg_temp.v_edges_test',
        'public.routing_vertices'
    );
    RAISE EXCEPTION 'Expected [GRAPH_STATE:CRITICAL_COLS_MISSING], but no error was raised';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLERRM LIKE '%[GRAPH_STATE:CRITICAL_COLS_MISSING]%' THEN
                RAISE NOTICE 'OK : expected error caught -> %', SQLERRM;
            ELSE
                RAISE EXCEPTION 'Unexpected error for TEST 3: %', SQLERRM;
        END IF;
END
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------------
-- TEST 4 : CRITICAL_COLS_MISSING — critical column(s) on vertice view exist(s) or not
--------------------------------------------------------------------------------------

\echo 'TEST 4: [GRAPH_STATE:CRITICAL_COLS_MISSING] on vertices view'

DROP TABLE IF EXISTS edges_test, vertices_test CASCADE;

CREATE TEMP table vertices_test(
    id integer
);

CREATE VIEW pg_temp.v_vertices_test AS
    SELECT * FROM pg_temp.vertices_test;

DO $$

BEGIN 
    PERFORM assert_graph_ready_on(
        'public.routing_edges', 
        'pg_temp.v_vertices_test'
    );
    RAISE EXCEPTION 'Expected [GRAPH_STATE:CRITICAL_COLS_MISSING], but no error was raised';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLERRM LIKE '%[GRAPH_STATE:CRITICAL_COLS_MISSING]%' THEN
                RAISE NOTICE 'OK : expected error caught -> %', SQLERRM;
            ELSE
                RAISE EXCEPTION 'unexpected error for TEST 4: %', SQLERRM;
            END IF;
END
$$ LANGUAGE plpgsql;


--------------------------------------------------------------------------------------
-- TEST 5 : GRAPH_STATE:EMPTY — graph must be non empty on edges view------------------
--------------------------------------------------------------------------------------

\echo 'TEST 5: [GRAPH_STATE:EMPTY] on edges view'

DROP TABLE IF EXISTS edges_test, vertices_test CASCADE;

CREATE TEMP TABLE edges_test(
    source double precision,
    target double precision,
    cost double precision,
    reverse_cost double precision, 
    geom geometry
);

CREATE VIEW pg_temp.v_edges_test AS
    SELECT * FROM pg_temp.edges_test;

DO $$

BEGIN
    PERFORM assert_graph_ready_on(
        'pg_temp.v_edges_test',
        'public.routing_vertices'
    );
    RAISE EXCEPTION 'Expected [GRAPH_STATE:EMPTY], but no error was raised';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLERRM LIKE '%[GRAPH_STATE:EMPTY]%' THEN
                RAISE NOTICE 'OK : expected error caught -> %', SQLERRM;
            ELSE
                RAISE EXCEPTION 'Unexpected error caught -> %', SQLERRM;
            END IF;
END
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------------
-- TEST 6 : GRAPH_STATE:EMPTY — graph must be non empty on vertices view---------------
--------------------------------------------------------------------------------------

\echo 'TEST 6: [GRAPH_STATE:EMPTY] on vertices view'

DROP TABLE IF EXISTS edges_test, vertices_test CASCADE;

CREATE TEMP TABLE vertices_test(
    id integer, 
    the_geom geometry
);

CREATE VIEW pg_temp.v_vertices_test AS
    SELECT * FROM pg_temp.vertices_test;

DO $$

BEGIN
    PERFORM assert_graph_ready_on(
        'public.routing_edges',
        'pg_temp.v_vertices_test'
        );
    RAISE EXCEPTION 'Expected [GRAPH_STATE:EMPTY], but no error was raised';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLERRM LIKE '%[GRAPH_STATE:EMPTY]%' THEN
                RAISE NOTICE 'OK : expected error caught -> %', SQLERRM;
            ELSE
                RAISE EXCEPTION 'Unexpected error caught -> %', SQLERRM;
            END IF;
END
$$ LANGUAGE plpgsql; 


--------------------------------------------------------------------------------------
-- TEST 7 : GRAPH_STATE:TOPOLOGY_NULL — cols source or target empty ------------------
--------------------------------------------------------------------------------------

\echo 'TEST 7 : [GRAPH_STATE:TOPOLOGY_NULL] no source or target values'

DROP TABLE IF EXISTS edges_test, vertices_test CASCADE;

CREATE TEMP TABLE edges_test(
    source double precision,
    target double precision,
    cost double precision,
    reverse_cost double precision, 
    geom geometry(Linestring, 2154)
);

INSERT INTO edges_test (source, target, cost, reverse_cost, geom)
VALUES (1, NULL, 10, 10, ST_GeomFromText('Linestring(0 0, 1 1)', 2154)); 

CREATE VIEW pg_temp.v_edges_test AS
    SELECT * FROM pg_temp.edges_test;

DO $$

BEGIN
    PERFORM assert_graph_ready_on(
        'pg_temp.v_edges_test', 
        'public.routing_vertices'
    );
    RAISE EXCEPTION 'Expected [GRAPH_STATE:TOPOLOGY_NULL], but no error was raised';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLERRM LIKE '%[GRAPH_STATE:TOPOLOGY_NULL]%' THEN
                RAISE NOTICE 'OK : expected error caught -> %', SQLERRM;
            ELSE
                RAISE EXCEPTION 'Unexpected error caught -> %', SQLERRM;
            END IF;
END
$$ LANGUAGE plpgsql;

--------------------------------------------------------------------------------------
-- TEST 8 : GRAPH_STATE:COST_NULL — cols cost or reverse_cost empty ------------------
--------------------------------------------------------------------------------------

\echo 'TEST 8 : : [GRAPH_STATE:COST_NULL] no cost or reverse_cost values'

DROP TABLE IF EXISTS edges_test, vertices_test CASCADE; 

CREATE TEMP TABLE edges_test(
    source double precision,
    target double precision,
    cost double precision,
    reverse_cost double precision, 
    geom geometry(Linestring, 2154)
);

INSERT INTO edges_test (source, target, cost, reverse_cost, geom)
VALUES (1, 1, NULL, 1, ST_GeomFromText('Linestring(0 0, 1 1)', 2154));

CREATE VIEW pg_temp.v_edges_test AS
    SELECT * FROM pg_temp.edges_test;

DO $$

BEGIN
    PERFORM assert_graph_ready_on(
        'pg_temp.v_edges_test',
        'public.routing_vertices'
    );
    RAISE EXCEPTION 'Expected [GRAPH_STATE:COST_NULL], but no error was raised';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLERRM LIKE '%[GRAPH_STATE:COST_NULL]%' THEN
                RAISE NOTICE 'OK : expected error caught -> %', SQLERRM;
            ELSE
                RAISE EXCEPTION 'Unexpected error caught -> %', SQLERRM;
            END IF; 
END
$$ LANGUAGE plpgsql; 


--------------------------------------------------------------------------------------
-- TEST 9 : GRAPH_STATE:GEOM_ALL_NULL — column geom has no non NULL geometries (edges)
--------------------------------------------------------------------------------------

\echo 'TEST 9 : [GRAPH_STATE:GEOM_ALL_NULL] no non NULL values in geom on the edges view'

DROP TABLE IF EXISTS edges_test, vertices_test CASCADE; 

CREATE TEMP TABLE edges_test(
    source double precision,
    target double precision,
    cost double precision,
    reverse_cost double precision, 
    geom geometry(Linestring, 2154)
);

INSERT INTO edges_test (source, target, cost, reverse_cost, geom)
VALUES (1, 1, 1, 1, NULL);

CREATE VIEW pg_temp.v_edges_test AS
    SELECT * FROM pg_temp.edges_test;

DO $$ 

BEGIN
    PERFORM assert_graph_ready_on(
        'pg_temp.v_edges_test',
        'public.routing_vertices'
    );
    RAISE EXCEPTION 'Expected [GRAPH_STATE:GEOM_ALL_NULL], but no error was raised';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLERRM LIKE '%[GRAPH_STATE:GEOM_ALL_NULL]%' THEN
                RAISE NOTICE 'OK : expected error caught -> %', SQLERRM;
            ELSE
                RAISE EXCEPTION 'Unexpected error caught -> %', SQLERRM;
            END IF; 
END
$$ LANGUAGE plpgsql;

---------------------------------------------------------------------------------------
-- TEST 10 : GRAPH_STATE:SRID_MISMATCH — SRID consistency on the edges view's geometry
---------------------------------------------------------------------------------------

\echo 'TEST 10 : [GRAPH_STATE:SRID_MISMATCH] SRID consistency on the edges view geometry'

DROP TABLE IF EXISTS edges_test, vertices_test CASCADE; 

CREATE TEMP TABLE edges_test(
    source double precision,
    target double precision,
    cost double precision,
    reverse_cost double precision, 
    geom geometry(Linestring, 4326)
);

INSERT INTO edges_test (source, target, cost, reverse_cost, geom)
VALUES (1, 1, 1, 1, ST_GeomFromText('LINESTRING(0 0, 1 1)', 4326));

CREATE VIEW pg_temp.v_edges_test AS
    SELECT * FROM pg_temp.edges_test;

DO $$ 

BEGIN
    PERFORM assert_graph_ready_on(
        'pg_temp.v_edges_test',
        'public.routing_vertices'
    );
    RAISE EXCEPTION 'Expected [GRAPH_STATE:SRID_MISMATCH], but no error was raised';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLERRM LIKE '%[GRAPH_STATE:SRID_MISMATCH]%' THEN
                RAISE NOTICE 'OK : expected error caught -> %', SQLERRM;
            ELSE
                RAISE EXCEPTION 'Unexpected error caught -> %', SQLERRM;
            END IF; 
END
$$ LANGUAGE plpgsql; 

--------------------------------------------------------------------------------------
-- TEST 11 : GRAPH_STATE:GEOM_ALL_NULL — column geom has no non NULL geometries (vertices)
--------------------------------------------------------------------------------------

\echo 'TEST 11 : [GRAPH_STATE:GEOM_ALL_NULL] no non NULL values in geom on the vertices view'

DROP TABLE IF EXISTS edges_test, vertices_test CASCADE; 

CREATE TEMP TABLE vertices_test(
    id integer,
    the_geom geometry(Point, 2154)
);

INSERT INTO vertices_test (id, the_geom)
VALUES (1, NULL);

CREATE VIEW pg_temp.v_vertices_test AS
    SELECT * FROM pg_temp.vertices_test;

DO $$ 

BEGIN
    PERFORM assert_graph_ready_on(
        'public.routing_edges',
        'pg_temp.v_vertices_test'
    );
    RAISE EXCEPTION 'Expected [GRAPH_STATE:GEOM_ALL_NULL], but no error was raised';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLERRM LIKE '%[GRAPH_STATE:GEOM_ALL_NULL]%' THEN
                RAISE NOTICE 'OK : expected error caught -> %', SQLERRM;
            ELSE
                RAISE EXCEPTION 'Unexpected error caught -> %', SQLERRM;
            END IF; 
END
$$ LANGUAGE plpgsql;

------------------------------------------------------------------------------------------
-- TEST 12 : GRAPH_STATE:SRID_MISMATCH — SRID consistency on the vertices view's geometry
------------------------------------------------------------------------------------------

\echo 'TEST 12 : [GRAPH_STATE:SRID_MISMATCH] SRID consistency on the vertices view geometry'

DROP TABLE IF EXISTS edges_test, vertices_test CASCADE; 

CREATE TEMP TABLE vertices_test(
    id integer,
    the_geom geometry(Point, 4326)
);

INSERT INTO vertices_test (id, the_geom)
VALUES (1, ST_GeomFromText('POINT(0 0)', 4326));

CREATE VIEW pg_temp.v_vertices_test AS
    SELECT * FROM pg_temp.vertices_test;

DO $$ 

BEGIN
    PERFORM assert_graph_ready_on(
        'public.routing_edges',
        'pg_temp.v_vertices_test'
    );
    RAISE EXCEPTION 'Expected [GRAPH_STATE:SRID_MISMATCH], but no error was raised';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLERRM LIKE '%[GRAPH_STATE:SRID_MISMATCH]%' THEN
                RAISE NOTICE 'OK : expected error caught -> %', SQLERRM;
            ELSE
                RAISE EXCEPTION 'Unexpected error caught -> %', SQLERRM;
            END IF; 
END
$$ LANGUAGE plpgsql; 

--------------------------------
-- TEST 13 : SUCCESS CASE ------
--------------------------------

\echo 'TEST 13 : SUCCESS CASE'

DROP TABLE IF EXISTS edges_test, vertices_test CASCADE; 

CREATE TEMP TABLE edges_test(
    source double precision,
    target double precision,
    cost double precision,
    reverse_cost double precision, 
    geom geometry(Linestring, 2154)
);

INSERT INTO edges_test (source, target, cost, reverse_cost, geom)
VALUES (1, 1, 1, 1, ST_GeomFromText('LINESTRING(0 0, 1 1)', 2154));

CREATE VIEW pg_temp.v_edges_test AS
    SELECT * FROM pg_temp.edges_test;

CREATE TEMP TABLE vertices_test(
    id integer,
    the_geom geometry(Point, 2154)
);

INSERT INTO vertices_test (id, the_geom)
VALUES (1, ST_GeomFromText('POINT(0 0)', 2154));

CREATE VIEW pg_temp.v_vertices_test AS
    SELECT * FROM pg_temp.vertices_test;

DO $$ 

BEGIN
    PERFORM assert_graph_ready_on(
        'pg_temp.v_edges_test',
        'pg_temp.v_vertices_test'
    );
    RAISE NOTICE 'OK : success case, no error raised';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Unexpected error for TEST 13: %', SQLERRM;
END
$$ LANGUAGE plpgsql; 

\echo ''

\echo '============================================================'
\echo 'END TEST SUITE'
\echo '============================================================'