-- /SQL/01_config/routing_constants.sql
-- Central "source of truth" for routing engine constants.
-- Keep functions IMMUTABLE so they can be used inside expressions safely.

\echo ''
\echo '>>> START : /SQL/01_config/routing_constants.sql'
\echo ''

CREATE OR REPLACE FUNCTION routing_graph_srid()
RETURNS integer
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT 2154::integer;
$$;

\echo ''
\echo 'routing_graph_srid function created'
\echo ''

CREATE OR REPLACE FUNCTION routing_api_srid()
RETURNS integer
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT 4326::integer;
$$;

\echo ''
\echo 'routing_graph_api function created'
\echo ''

-- Optional (next step)
CREATE OR REPLACE FUNCTION routing_topology_tolerance_m()
RETURNS double precision
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT 1.0::double precision;
$$;

\echo ''
\echo 'routing_topology_tolerance function created'
\echo ''


-- Optional (next step)
CREATE OR REPLACE FUNCTION routing_bbox_buffer_ratio()
RETURNS double precision
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT 0.30::double precision;
$$;

\echo ''
\echo 'routing_bbox_buffer_ratio function created'
\echo ''

\echo ''
\echo '<<< END   : /SQL/01_config/routing_constants.sql'
\echo ''