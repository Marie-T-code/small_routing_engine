-- SQL/04_graph/02_graph_creation/00_assert_graph_preconditions_on.sql
-- guardrail function, core general logic
-- checks minimum viable data state without which the graph can't be created
-- silent validation raise errors if something is missing

\echo ''
\echo '>>> START : /SQL/04_graph/02_graph_creation/00_assert_graph_preconditions_on.sql'
\echo ''

CREATE OR REPLACE FUNCTION assert_graph_preconditions_on(p_table_name text)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    expected_srid int := routing_graph_srid();
    actual_srid   int;
    has_length_m_nulls boolean;
    v_rel regclass;
BEGIN
  -- resolve relation
  v_rel := to_regclass(p_table_name);

  -- 1) Table exists
  IF v_rel IS NULL THEN
    RAISE EXCEPTION
      '[GRAPH:TABLE_MISSING] % does not exist (run import step)', p_table_name
      USING ERRCODE = 'P0001';
  END IF;
  -- 2) Required columns exist
  IF NOT EXISTS (
    SELECT 1
    FROM pg_attribute
    WHERE attrelid = v_rel
      AND attname = 'geom'
      AND NOT attisdropped
      AND attnum > 0
  ) THEN
    RAISE EXCEPTION
      '[GRAPH:COL_GEOM_MISSING] %.geom is missing (run import step)', p_table_name
      USING ERRCODE = 'P0001';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_attribute
    WHERE attrelid = v_rel
      AND attname = 'fid'
      AND NOT attisdropped
      AND attnum > 0
  ) THEN
    RAISE EXCEPTION
      '[GRAPH:COL_FID_MISSING] %.fid is missing (required by pgr_createTopology)', p_table_name
      USING ERRCODE = 'P0001';
  END IF;

  IF NOT EXISTS(
    SELECT 1
    FROM pg_attribute
    WHERE attrelid = v_rel
      AND attname = 'cost'
      AND NOT attisdropped
      AND attnum > 0
  ) OR NOT EXISTS(
    SELECT 1
    FROM pg_attribute
    WHERE attrelid = v_rel
      AND attname = 'reverse_cost'
      AND NOT attisdropped
      AND attnum > 0 
  ) THEN
  RAISE EXCEPTION
    '[GRAPH:COST_COLS_MISSING] cost/reverse_cost columns are missing (run costs configuration step)'
      USING ERRCODE = 'P0001';
  END IF;

  -- 3) SRID check (critical)
  EXECUTE format(
    'SELECT ST_SRID(geom)
    FROM %s
    WHERE geom IS NOT NULL
    LIMIT 1',
    v_rel
  )
  INTO actual_srid;

  IF actual_srid IS NULL THEN
    RAISE EXCEPTION
    '[GRAPH:GEOM_ALL_NULL] %.geom contains no non-NULL geometries', p_table_name
      USING ERRCODE = 'P0001';
  END IF;

  IF actual_srid <> expected_srid THEN
    RAISE EXCEPTION
    '[GRAPH:SRID_MISMATCH] %.geom SRID is %, expected %.',
      p_table_name, actual_srid, expected_srid
      USING ERRCODE = 'P0001';
  END IF;

  -- 4) Sanity : length_m exists and is populated

  IF EXISTS (
    SELECT 1
    FROM pg_attribute
    WHERE attrelid = v_rel
    AND attname = 'length_m'
    AND NOT attisdropped
    AND attnum > 0
  ) THEN
    EXECUTE format(
      'SELECT EXISTS(
      SELECT 1
      FROM %s
      WHERE length_m IS NULL
      LIMIT 1
      )',
      v_rel
    )
    INTO has_length_m_nulls; 

    IF has_length_m_nulls THEN
      RAISE EXCEPTION
        '[GRAPH:LENGTH_M_NULLS] %.length_m contains NULL values (run SQL/04_graph/01_pre_processing/02_add_length_m.sql)',
        p_table_name
        USING ERRCODE = 'P0001';
    END IF; 
  END IF;

  RETURN; 
END;
$$;

\echo ''
\echo '<<< END   : /SQL/04_graph/02_graph_creation/00_assert_graph_preconditions_on.sql'
\echo ''