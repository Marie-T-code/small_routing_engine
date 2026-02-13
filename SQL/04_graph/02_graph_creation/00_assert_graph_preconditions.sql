-- SQL/04_graph/02_graph_creation/00_assert_graph_preconditions.sql
-- guardrail function
-- checks minimum viable data state without which the graph can't be created
-- silent validation raise errors if something is missing

\echo ''
\echo '>>> START : /SQL/04_graph/02_graph_creation/00_assert_graph_preconditions.sql'
\echo ''

CREATE OR REPLACE FUNCTION assert_graph_preconditions()
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  expected_srid int := routing_graph_srid();
  actual_srid   int;
BEGIN
  -- 1) Table exists
  IF to_regclass('public.routes_v1') IS NULL THEN
    RAISE EXCEPTION
      '[GRAPH:TABLE_MISSING] public.routes_v1 does not exist (run import step)'
      USING ERRCODE = 'P0001';
  END IF;

  -- 2) Required columns exist (cheap checks)
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema='public' AND table_name='routes_v1' AND column_name='geom'
  ) THEN
    RAISE EXCEPTION
      '[GRAPH:COL_GEOM_MISSING] public.routes_v1.geom is missing'
      USING ERRCODE = 'P0001';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema='public' AND table_name='routes_v1' AND column_name='fid'
  ) THEN
    RAISE EXCEPTION
      '[GRAPH:COL_FID_MISSING] public.routes_v1.fid is missing (required by pgr_createTopology)'
      USING ERRCODE = 'P0001';
  END IF;

  -- (Optional but recommended) cost fields exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='routes_v1' AND column_name='cost'
  ) OR NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='routes_v1' AND column_name='reverse_cost'
  ) THEN
    RAISE EXCEPTION
      '[GRAPH:COST_COLS_MISSING] cost/reverse_cost columns are missing (run costs configuration step)'
      USING ERRCODE = 'P0001';
  END IF;

  -- 3) SRID check (critical)
  SELECT ST_SRID(geom)
  INTO actual_srid
  FROM public.routes_v1
  WHERE geom IS NOT NULL
  LIMIT 1;

  IF actual_srid IS NULL THEN
    RAISE EXCEPTION
      '[GRAPH:GEOM_ALL_NULL] routes_v1.geom contains no non-NULL geometries'
      USING ERRCODE = 'P0001';
  END IF;

  IF actual_srid <> expected_srid THEN
    RAISE EXCEPTION
      '[GRAPH:SRID_MISMATCH] routes_v1.geom SRID is %, expected % (routing_graph_srid())',
      actual_srid, expected_srid
      USING ERRCODE = 'P0001';
  END IF;

  -- 4) Sanity: length_m exists and is populated (optional but helpful)
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='routes_v1' AND column_name='length_m'
  ) THEN
    IF EXISTS (
      SELECT 1 FROM public.routes_v1 WHERE length_m IS NULL LIMIT 1
    ) THEN
      RAISE EXCEPTION
        '[GRAPH:LENGTH_M_NULLS] routes_v1.length_m contains NULL values (run SQL/04_graph/01_pre_processing/02_add_length_m.sql)'
        USING ERRCODE = 'P0001';
    END IF;
  END IF;

  -- If we reach here: OK (silent success)
  RETURN;
END;
$$;


\echo ''
\echo '<<< END   : /SQL/04_graph/02_graph_creation/00_assert_graph_preconditions.sql'
\echo ''