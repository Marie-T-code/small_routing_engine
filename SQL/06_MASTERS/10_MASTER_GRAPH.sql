-- /SQL/06_MASTERS/10_MASTER_GRAPH.sql

\echo ''
\echo '>>> START : /SQL/06_MASTERS/10_MASTER_GRAPH.sql'
\echo ''

\echo '--- PREPROCESSING ---'
\echo '---------------------'


\echo '--- Clean the table structure after ogr2ogr import ---'
\i /SQL/04_graph/01_pre_processing/01_clean_table_structure.sql

\echo '--- Compute edge lengths in meters (length_m) for each edge of the future graph. ---'
\i /SQL/04_graph/01_pre_processing/02_add_length_m.sql

\echo '--- Configure routing weights (cost / reverse_cost) before building the pgRouting topology. ---'
\i /SQL/04_graph/01_pre_processing/03_costs_config.sql

\echo '--- removing false edges from the routes_v1(edges) table ---'
\i /SQL/04_graph/01_pre_processing/04_edges_cleaning.sql

\echo '--- GRAPH CREATION ---'
\echo '----------------------'

\echo '--- Define guardrail function assert_graph_preconditions_on() used by assert_graph_preconditions. This generic guardrail checks minimum viable data state without which the graph cannot be created ---'
\i /SQL/04_graph/04_guardrails/assert_graph_preconditions_on.sql

\echo '--- Define wrapper guardrail function assert_graph_preconditions() ---'
\i /SQL/04_graph/04_guardrails/assert_graph_preconditions.sql

\echo '--- Create pgRouting topology from the routes_v1 table ---'
\i /SQL/04_graph/02_graph_creation/01_PGRouting_createTopology_graph_creation.sql

\echo '--- GRAPH ANALYSIS ---'
\echo '----------------------'

\echo '--- Topology check on the final graph after cleaning ---'
\i /SQL/04_graph/02_graph_creation/02_analyzeGraph.sql

\echo '--- Verify required indexes exist for routing performance ---'
\i /SQL/04_graph/02_graph_creation/03_check_indexes.sql


\echo '--- Length sanity checks after graph creation ---'
\i /SQL/04_graph/02_graph_creation/04_edges_check.sql


\echo '--- VIEWS ---'
\echo '-------------'

\echo '--- Provide a stable, canonical view of routing edges for all routing algorithms. ---'
\i /SQL/04_graph/03_views/routing_edges.sql

\echo '--- Provides a stable, canonical view of routing vertices for all routing algorithms. ---'
\i /SQL/04_graph/03_views/routing_vertices.sql

\echo '--- POST-BUILD GUARDRAIL ---'
\echo '---------------------------'

\echo '--- Define generic guardrail assert_graph_ready_on() ---'
\i /SQL/04_graph/04_guardrails/assert_graph_ready_on.sql
\echo '--- Define wrapper assert_graph_ready() ---'
\i /SQL/04_graph/04_guardrails/assert_graph_ready.sql
\echo '--- Execute post-build graph state check ---'
SELECT assert_graph_ready();

\echo '--- POST-BUILD GRAPH BOUNGIN BOX ---'
\echo '-----------------------------------'

\echo 'Computes graph coverage and stores the resulting polygon (EPSG:4326) in graph_coverage.'
\i /SQL/04_graph/05_coverage/compute_graph_bbox.sql


\echo ''
\echo '>>> END : /SQL/06_MASTERS/10_MASTER_GRAPH.sql'
\echo ''