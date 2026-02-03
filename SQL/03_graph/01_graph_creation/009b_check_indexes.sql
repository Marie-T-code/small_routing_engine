-- 009b_check_indexes.sql
-- Purpose: Verify required indexes exist for routing performance

SELECT
  indexname,
  tablename
FROM pg_indexes
WHERE tablename IN ('routes_v1', 'routes_v1_vertices_pgr')
ORDER BY tablename, indexname;