-- SQL/04_graph/02_graph_creation/00_assert_graph_preconditions.sql
-- wrapper guardrail function (production-ready, checks actual table table) for SQL/04_graph/02_graph_creation/00_assert_graph_preconditions_on.sql
-- checks minimum viable data state without which the graph can't be created
-- silent validation raise errors if something is missing

\echo ''
\echo '>>> START : /SQL/04_graph/02_graph_creation/00_assert_graph_preconditions.sql'
\echo ''


CREATE OR REPLACE FUNCTION assert_graph_preconditions()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM assert_graph_preconditions_on('public.routes_v1');
END;
$$;


\echo ''
\echo '<<< END   : /SQL/04_graph/02_graph_creation/00_assert_graph_preconditions.sql'
\echo ''