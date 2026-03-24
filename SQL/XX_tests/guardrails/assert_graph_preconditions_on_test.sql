-- /SQL/XX_tests/guardrails/assert_graph_preconditions_on_test.sql

\echo ''
\echo '============================================================'
\echo 'TEST SUITE : assert_graph_preconditions_on()'
\echo '============================================================'
\echo ''

-----------------------------------------------------------------
-- TEST 1 : TABLE MISSING
-----------------------------------------------------------------

\echo 'TEST 1 : TABLE_MISSING'

DROP TABLE IF EXISTS routes_test; 

DO $$
BEGIN
    PERFORM assert_graph_preconditions_on('pg_temp.routes_test');
    RAISE EXCEPTION 'Expected [GRAPH:TABLE_MISSING], but no error was raised';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLERRM LIKE '%[GRAPH:TABLE_MISSING]%' THEN
            RAISE NOTICE 'OK : expected error caught -> %', SQLERRM;
        ELSE
            RAISE EXCEPTION 'Unexpected error for TEST 1: %', SQLERRM;
        END IF;
END
$$ LANGUAGE plpgsql;

-----------------------------------------------------------------
-- TEST 2 : COL_GEOM_MISSING
-----------------------------------------------------------------

\echo 'TEST 2 : COL_GEOM_MISSING'

DROP TABLE IF EXISTS routes_test; 

CREATE TEMP TABLE routes_test(
    fid integer,
    cost double precision,
    reverse_cost double precision
);

DO $$
BEGIN
    PERFORM assert_graph_preconditions_on('pg_temp.routes_test');
    RAISE EXCEPTION 'Expected [GRAPH:COL_GEOM_MISSING], but no error was raised';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLERRM LIKE '%[GRAPH:COL_GEOM_MISSING]%' THEN
            RAISE NOTICE 'OK : expected error caught -> %', SQLERRM;
        ELSE
            RAISE EXCEPTION 'Unexpected error for TEST 2 :%', SQLERRM;
        END IF; 
END
$$ LANGUAGE plpgsql;

-----------------------------------------------------------------
-- TEST 3 : COL_FID_MISSING
-----------------------------------------------------------------

\echo 'TEST 3 : COL_FID_MISSING'

DROP TABLE IF EXISTS routes_test; 

CREATE TEMP TABLE routes_test (
    geom geometry(Linestring, 2154),
    cost double precision, 
    reverse_cost double precision
);

DO $$
BEGIN
    PERFORM assert_graph_preconditions_on('pg_temp.routes_test');
    RAISE EXCEPTION 'Expected [GRAPH:COL_FID_MISSING], but no error was raised';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLERRM LIKE '%[GRAPH:COL_FID_MISSING]%' THEN
            RAISE NOTICE 'OK : expected error caught -> %', SQLERRM;
        ELSE
            RAISE EXCEPTION 'Unexcpected error for TEST 3: %', SQLERRM; 
        END IF;
END
$$ LANGUAGE plpgsql;

-----------------------------------------------------------------
-- TEST 4 : COST_COLS_MISSING
-----------------------------------------------------------------

\echo 'TEST 4 : COST_COLS_MISSING'

DROP TABLE IF EXISTS routes_test;

CREATE TEMP TABLE routes_test (
    fid integer,
    geom geometry(Linestring, 2154)
);

DO $$
BEGIN
    PERFORM assert_graph_preconditions_on('pg_temp.routes_test');
    RAISE EXCEPTION 'Expected [GRAPH:COST_COLS_MISSING], but no error was raised';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLERRM LIKE'%[GRAPH:COST_COLS_MISSING]%' THEN
            RAISE NOTICE 'OK : expected error caught -> %', SQLERRM;
        ELSE
            RAISE EXCEPTION 'Unexpected error for TEST 4: %', SQLERRM;
        END IF;
END
$$ LANGUAGE plpgsql;

-----------------------------------------------------------------
-- TEST 5 : GEOM_ALL_NULL
-----------------------------------------------------------------

\echo 'TEST 5 : GEOM_ALL_NULL'

DROP TABLE IF EXISTS routes_test;

CREATE TEMP TABLE routes_test(
    fid integer, 
    geom geometry(Linestring, 2154),
    cost double precision, 
    reverse_cost double precision
);

INSERT INTO routes_test (fid, geom, cost, reverse_cost)
VALUES (1, NULL, 10, 10);

DO $$
BEGIN
    PERFORM assert_graph_preconditions_on('pg_temp.routes_test');
    RAISE EXCEPTION 'Expected [GRAPH:GEOM_ALL_NULL], but no error was raised';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLERRM LIKE '%[GRAPH:GEOM_ALL_NULL]%' THEN
            RAISE NOTICE 'OK : expected error caught -> %', SQLERRM;
        ELSE
            RAISE EXCEPTION 'Unexpected error for TEST 5 : %', SQLERRM;
        END IF; 
END
$$ LANGUAGE plpgsql;

-----------------------------------------------------------------
-- TEST 6 : SRID_MISMATCH
-----------------------------------------------------------------

\echo 'TEST 6 : SRID_MISMATCH'

DROP TABLE IF EXISTS routes_test; 

CREATE TEMP TABLE routes_test (
    fid integer, 
    geom geometry(Linestring, 4326),
    cost double precision,
    reverse_cost double precision
);

INSERT INTO routes_test (fid, geom, cost, reverse_cost)
VALUES (
    1, 
    ST_GeomFromText('LINESTRING(0 0, 1 1)', 4326),
    10,
    10
);

DO $$
BEGIN
    PERFORM assert_graph_preconditions_on('pg_temp.routes_test');
    RAISE EXCEPTION 'Expected [GRAPH:SRID_MISMATCH], but no error was raised';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLERRM LIKE '%[GRAPH:SRID_MISMATCH]%' THEN
            RAISE NOTICE 'OK : expected error caught -> %', SQLERRM;
        ELSE
            RAISE EXCEPTION 'Unexpected error for TEST 6: %', SQLERRM;
        END IF;
END
$$ LANGUAGE plpgsql;

-----------------------------------------------------------------
-- TEST 7 : LENGTH_M_NULLS
-----------------------------------------------------------------

\echo 'TEST 7 : LENGTH_M_NULLS'

DROP TABLE IF EXISTS routes_test; 

CREATE TEMP TABLE routes_test (
    fid integer,
    geom geometry(Linestring, 2154),
    cost double precision, 
    reverse_cost double precision, 
    length_m double precision
);

INSERT INTO routes_test (fid, geom, cost, reverse_cost, length_m)
VALUES (
    1,
    ST_GeomFromText('Linestring(0 0, 1 1)', 2154), 
    10,
    10,
    NULL
);

DO $$
BEGIN
    PERFORM assert_graph_preconditions_on('pg_temp.routes_test');
    RAISE EXCEPTION 'Expected [GRAPH:LENGTH_M_NULLS], but no error was raised';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLERRM LIKE '%[GRAPH:LENGTH_M_NULLS]%' THEN
            RAISE NOTICE 'OK : expected error caught -> %', SQLERRM;
        ELSE
            RAISE EXCEPTION 'Unexpected error for TEST 7: %', SQLERRM;
        END IF;
END
$$ LANGUAGE plpgsql;

-----------------------------------------------------------------
-- TEST 8 : SUCCESS CASE
-----------------------------------------------------------------

\echo 'TEST 8 : SUCCESS CASE'

DROP TABLE IF EXISTS routes_test;

CREATE TEMP TABLE routes_test(
    fid integer,
    geom geometry(Linestring, 2154),
    cost double precision, 
    reverse_cost double precision,
    length_m double precision
);

INSERT INTO routes_test (fid, geom, cost, reverse_cost, length_m)
VALUES(
    1,
    ST_GeomFromText('LINESTRING(0 0,1 1 )', 2154),
    10,
    10,
    1.414
);

DO $$ 
BEGIN
    PERFORM assert_graph_preconditions_on('pg_temp.routes_test');
    RAISE NOTICE 'OK : success case, no error raised';
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Unexpected error for TEST 8: %', SQLERRM;
END
$$ LANGUAGE plpgsql;

\echo ''

\echo '============================================================'
\echo 'END TEST SUITE'
\echo '============================================================'