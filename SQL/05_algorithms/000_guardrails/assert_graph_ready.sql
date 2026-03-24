-- /SQL/05_algorithms/000_guardrails/assert_graph_ready.sql
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

CREATE OR REPLACE FUNCTION public.assert_graph_ready()
RETURNS void
LANGUAGE plpgsql
AS
$$
DECLARE
    v_edges_count    bigint;
    v_vertices_count bigint;
    v_expected_srid  integer := routing_graph_srid();
    v_actual_srid    integer;
BEGIN

    -- 1) Required views must exist
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.views
        WHERE table_schema = 'public'
          AND table_name = 'routing_edges'
    ) THEN
        RAISE EXCEPTION
            'GRAPH_STATE:VIEWS_MISSING | routing_edges view missing (run MASTER_GRAPH).'
            USING ERRCODE = 'P0001';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.views
        WHERE table_schema = 'public'
          AND table_name = 'routing_vertices'
    ) THEN
        RAISE EXCEPTION
            'GRAPH_STATE:VIEWS_MISSING | routing_vertices view missing (run MASTER_GRAPH).'
            USING ERRCODE = 'P0001';
    END IF;

    -- 2) Critical columns must exist on the views
    -- routing_edges: source / target / cost / reverse_cost / geom
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'routing_edges'
          AND column_name = 'source'
    ) OR NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'routing_edges'
          AND column_name = 'target'
    ) OR NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'routing_edges'
          AND column_name = 'cost'
    ) OR NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'routing_edges'
          AND column_name = 'reverse_cost'
    ) OR NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'routing_edges'
          AND column_name = 'geom'
    ) THEN
        RAISE EXCEPTION
            'GRAPH_STATE:CRITICAL_COLS_MISSING | routing_edges missing critical columns (source/target/cost/reverse_cost/geom).'
            USING ERRCODE = 'P0001';
    END IF;

    -- routing_vertices: id / the_geom
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'routing_vertices'
          AND column_name = 'id'
    ) THEN
        RAISE EXCEPTION
            'GRAPH_STATE:CRITICAL_COLS_MISSING | routing_vertices missing id column.'
            USING ERRCODE = 'P0001';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'routing_vertices'
          AND column_name = 'the_geom'
    ) THEN
        RAISE EXCEPTION
            'GRAPH_STATE:CRITICAL_COLS_MISSING | routing_vertices missing the_geom column.'
            USING ERRCODE = 'P0001';
    END IF;


    -- 3) Graph must be non-empty
    SELECT COUNT(*) INTO v_edges_count
    FROM public.routing_edges;

    IF v_edges_count = 0 THEN
        RAISE EXCEPTION
            'GRAPH_STATE:EMPTY | routing_edges is empty (run MASTER_GRAPH).'
            USING ERRCODE = 'P0001';
    END IF;

    SELECT COUNT(*) INTO v_vertices_count
    FROM public.routing_vertices;

    IF v_vertices_count = 0 THEN
        RAISE EXCEPTION
            'GRAPH_STATE:EMPTY | routing_vertices is empty (run MASTER_GRAPH).'
            USING ERRCODE = 'P0001';
    END IF;

    -- 4) No NULLs in critical graph fields
    IF EXISTS (
        SELECT 1
        FROM public.routing_edges
        WHERE source IS NULL
           OR target IS NULL
    ) THEN
        RAISE EXCEPTION
            'GRAPH_STATE:TOPOLOGY_NULL | routing_edges has NULL source/target (topology not built).'
            USING ERRCODE = 'P0001';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.routing_edges
        WHERE cost IS NULL
           OR reverse_cost IS NULL
    ) THEN
        RAISE EXCEPTION
            'GRAPH_STATE:COST_NULL | routing_edges has NULL cost/reverse_cost (run costs configuration step).'
            USING ERRCODE = 'P0001';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.routing_edges
        WHERE geom IS NOT NULL
    ) THEN
        RAISE EXCEPTION
            'GRAPH_STATE:GEOM_ALL_NULL | routing_edges has no non-NULL geometries.'
            USING ERRCODE = 'P0001';
    END IF;

    -- 5) SRID consistency on routing_edges geometries
    SELECT ST_SRID(geom)
    INTO v_actual_srid
    FROM public.routing_edges
    WHERE geom IS NOT NULL
    LIMIT 1;

    IF v_actual_srid <> v_expected_srid THEN
        RAISE EXCEPTION
            'GRAPH_STATE:SRID_MISMATCH | routing_edges.geom SRID is %, expected %.',
            v_actual_srid, v_expected_srid
            USING ERRCODE = 'P0001';
    END IF;

END;
$$;