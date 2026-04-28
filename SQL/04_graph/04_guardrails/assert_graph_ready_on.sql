-- SQL/04_graph/04_guardrails/assert_graph_ready_on.sql
-- guardrail function, core general logic
-- graph state guardrail (post-build)

------------------------------------------------------------------
-- GRAPH_STATE guardrail (post-build)
-- Ensures the routing graph artifacts exist and are usable:
-- - required views exist
-- - graph is non-empty
-- - critical columns exist
-- - no NULLs in critical graph fields
-- - SRID is consistent with routing_graph_srid()
------------------------------------------------------------------

\echo ''
\echo '>>> START : SQL/04_graph/04_guardrails/assert_graph_ready_on.sql'
\echo ''

CREATE OR REPLACE FUNCTION public.assert_graph_ready_on(p_edges_view text, p_vertices_view text)
RETURNS void
LANGUAGE plpgsql
as $$
DECLARE
    v_edges_count              bigint;
    v_vertices_count           bigint;
    v_expected_srid            integer := routing_graph_srid();
    v_actual_srid              integer;
    v_edges_rel regclass;
    v_vertices_rel regclass;
    has_source_or_target_nulls boolean;
    has_costs_nulls            boolean;
    has_any_geom               boolean;

BEGIN

    -- 1) Required views must exist

    v_edges_rel := to_regclass(p_edges_view);
    v_vertices_rel := to_regclass(p_vertices_view);

    IF v_edges_rel IS NULL THEN
        RAISE EXCEPTION
            '[GRAPH_STATE:VIEWS_MISSING] % view missing (run MASTER_GRAPH).', p_edges_view
            USING ERRCODE = 'P0001';
    END IF;

    IF v_vertices_rel IS NULL THEN
        RAISE EXCEPTION
            '[GRAPH_STATE:VIEWS_MISSING] % view missing (run MASTER_GRAPH).', p_vertices_view
            USING ERRCODE = 'P0001';
    END IF;

    -- 2) Critical columns must exist on the views
    -- routing_edges: source / target / cost / reverse_cost / geom

    IF NOT EXISTS (
        SELECT 1
        FROM pg_attribute
        WHERE attrelid = v_edges_rel
            AND attname = 'source'
            AND NOT attisdropped
            AND attnum > 0
    ) OR NOT EXISTS (
        SELECT 1
        FROM pg_attribute
        WHERE attrelid = v_edges_rel
            AND attname = 'target'
            AND NOT attisdropped
            AND attnum > 0

    ) OR NOT EXISTS (
        SELECT 1
        FROM pg_attribute
        WHERE attrelid = v_edges_rel
            AND attname = 'cost'
            AND NOT attisdropped
            AND attnum > 0
    ) OR NOT EXISTS (
        SELECT 1
        FROM pg_attribute
        WHERE attrelid = v_edges_rel
            AND attname = 'reverse_cost'
            AND NOT attisdropped
            AND attnum > 0
    ) OR NOT EXISTS (
        SELECT 1
        FROM pg_attribute
        WHERE attrelid = v_edges_rel
            AND attname = 'geom'
            AND NOT attisdropped
            AND attnum > 0
    ) THEN
        RAISE EXCEPTION
            '[GRAPH_STATE:CRITICAL_COLS_MISSING] % missing critical columns (source/target/cost/reverse_cost/geom).', p_edges_view
            USING ERRCODE = 'P0001';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        from pg_attribute
        WHERE attrelid = v_vertices_rel
            AND attname = 'id'
            AND NOT attisdropped
            AND attnum > 0
    ) OR NOT EXISTS (
        SELECT 1
        FROM pg_attribute
        WHERE attrelid = v_vertices_rel
            AND attname = 'the_geom'
            AND NOT attisdropped
            AND attnum > 0
    ) THEN 
        RAISE EXCEPTION
            '[GRAPH_STATE:CRITICAL_COLS_MISSING] % missing critical columns (id/the_geom).', p_vertices_view
            USING ERRCODE = 'P0001';
    END IF;

    -- 3) Graph must be non empty

    
    EXECUTE format(
    'SELECT COUNT(*) FROM %s',
    v_edges_rel
    )
    
    INTO v_edges_count;

    IF v_edges_count = 0 THEN
        RAISE EXCEPTION
            '[GRAPH_STATE:EMPTY] % is empty (run MASTER_GRAPH).',p_edges_view
            USING ERRCODE = 'P0001';
    END IF;

    EXECUTE format(
        'SELECT COUNT(*) FROM %s', 
        v_vertices_rel
    )
    INTO v_vertices_count;

    IF v_vertices_count = 0 THEN
        RAISE EXCEPTION
            '[GRAPH_STATE:EMPTY] % is empty (run MASTER_GRAPH).',p_vertices_view
            USING ERRCODE = 'P0001';
    END IF;

    --4) No NULLS in critical graph fields

    EXECUTE format(
        'SELECT EXISTS
            (SELECT 1
            FROM %s
            WHERE source IS NULL OR target is NULL)', 
            v_edges_rel
    )
    INTO has_source_or_target_nulls;

    IF has_source_or_target_nulls THEN
        RAISE EXCEPTION
            '[GRAPH_STATE:TOPOLOGY_NULL] % has NULL source/target (topology not built).', p_edges_view
            USING ERRCODE = 'P0001';
    END IF;
    
    EXECUTE format(
        'SELECT EXISTS
            (SELECT 1
            FROM %s
            WHERE cost IS NULL or reverse_cost IS NULL)', 
            v_edges_rel
    )
    INTO has_costs_nulls;

    IF has_costs_nulls THEN
        RAISE EXCEPTION
            '[GRAPH_STATE:COST_NULL] % has NULL cost/reverse_cost (run costs configuration step).', p_edges_view
            USING ERRCODE = 'P0001';
    END IF;

    EXECUTE format(
        'SELECT EXISTS
            (SELECT 1
            FROM %s
            WHERE geom is NOT NULL)',
            v_edges_rel
    )
    INTO has_any_geom;

    IF NOT has_any_geom THEN
        RAISE EXCEPTION
            '[GRAPH_STATE:GEOM_ALL_NULL] % has no non-NULL geometries.', p_edges_view
            USING ERRCODE = 'P0001';
    END IF;

    -- 5) SRID consistency on the graph's view's geoometry

    EXECUTE format(
        'SELECT ST_SRID(geom)
        FROM %s
        WHERE geom IS NOT NULL
        LIMIT 1',
        v_edges_rel
    )
    INTO v_actual_srid;

    IF v_actual_srid <> v_expected_srid THEN
        RAISE EXCEPTION
            '[GRAPH_STATE:SRID_MISMATCH] %.geom SRID is %, expected %.',
            p_edges_view, v_actual_srid, v_expected_srid
            USING ERRCODE = 'P0001';
    END IF;

END;
$$;

\echo ''
\echo '<<< END   : SQL/04_graph/04_guardrails/assert_graph_ready_on.sql'
\echo ''