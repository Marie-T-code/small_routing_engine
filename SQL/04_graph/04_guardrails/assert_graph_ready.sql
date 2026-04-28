-- /SQL/04_graph/04_guardrails/assert_graph_ready.sql
-- graph state guardrail (post-build)
-- wrapper guardrail function (production-ready, checks actual views) for /SQL/04_graph/04_guardrails/assert_graph_ready_on.sql

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
\echo '>>> START : SQL/04_graph/04_guardrails/assert_graph_ready.sql'
\echo ''


CREATE OR REPLACE FUNCTION public.assert_graph_ready()
RETURNS void
LANGUAGE plpgsql
AS
$$
BEGIN
    PERFORM assert_graph_ready_on('public.routing_edges', 'public.routing_vertices');
END;
$$;

\echo ''
\echo '<<< END   : SQL/04_graph/04_guardrails/assert_graph_ready.sql'
\echo ''