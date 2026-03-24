# From data to API: Pipeline

This project builds a routing engine using PostGIS/pgRouting and exposes it through a Flask API.

## Pipeline overview

## Project structure

```
SMALL_ROUTING_ENGINE (fast routing on small, high-quality datasets)
├── app               (Flask API services)
├── DATA              (input datasets - cleaned .gpkg)
├── DB                (PostGIS image & init scripts)
├── docker
│   ├── builder       (graph build + routing functions service)
│   └── loader        (data import service)
├── documentation     (detailed project documentation)
├── exports           (output data / debug exports)
├── SQL
│   ├── 01_config     (routing constants: SRID, topology tolerance, default speeds)
│   ├── 02_views      (derived views after graph build)
│   ├── 03_injection  (data import into DB)
│   ├── 04_graph      (data preprocessing & graph build)
│   ├── 05_algorithms (routing functions - Dijkstra only)
│   ├── 06_MASTERS    (pipeline orchestration)
│   └── XX_tests      (guardrails & future validation tests)
├── .env              (environment variables)
├── .gitattributes
├── .gitignore
└── docker-compose.yaml (service orchestration)
```

## Pipeline steps

1. Clean spatial data is prepared in QGIS and stored in DATA/ (see [data_quality.md](/documentation/data_quality.md) for detailed cleaning process)

2. Docker starts the PostGIS/pgRouting database 
3. SQL scripts initialize the database at launch (extension, schema, indexes)
4. Data is imported into PostgreSQL 
5. costs are computed
6. Graph topology is computed
7. Routing functions (Dijkstra) are created

 **steps 2 to 7, see [docker.md](/documentation/docker.md)** 
 



8. Flask API sends SQL queries to PostgreSQL
9. The database returns routes (geometry + metrics)
