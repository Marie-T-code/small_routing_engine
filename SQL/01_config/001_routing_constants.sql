-- SQL/config/001_routing_constants.sql
-- Central "source of truth" for routing engine constants.
-- Keep functions IMMUTABLE so they can be used inside expressions safely.

CREATE OR REPLACE FUNCTION routing_graph_srid()
RETURNS integer
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT 2154::integer;
$$;

CREATE OR REPLACE FUNCTION routing_api_srid()
RETURNS integer
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT 4326::integer;
$$;

-- Optional (next step)
CREATE OR REPLACE FUNCTION routing_topology_tolerance_m()
RETURNS double precision
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT 1.0::double precision;
$$;

-- Optional (next step)
CREATE OR REPLACE FUNCTION routing_default_speed_kmh()
RETURNS double precision
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT 15.0::double precision;
$$;
