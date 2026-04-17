# Small Scale Routing Engine

A small-scale bike routing engine built with PostGIS/pgRouting, exposed through a Flask API.

> This project focuses on building a routing engine from scratch with full control over data, graph construction, and routing logic.

Dataset: road network of Nevers (France) + 15 km, single connected component (~76k edges)

> ⚠️ Work in progress — see [Known limitations & roadmap](#known-limitations--roadmap)

---

## in a hurry ?

Please check [Quick-start](#quick-start)  

---

## Why?

Can a pgr_dijkstra run on clean data, on a small area (Nevers + 15 km), in less than one second?  
Yes.

This project explores:
- fast routing on a limited territory
- customizable routing costs
- full ownership of the data
- a database-centered architecture with guardrails

Is it finished? No.  

Does it work? Yes.

Can it fail ? Well if it does it will tell you why (it should, at least)

---

## Project status

Functional backend prototype:

- data import pipeline works  
- graph build works  
- routing functions work  
- Flask API works  
- frontend not implemented yet  
- performance and testing still in progress  

---

## Main features

- import and clean a local road dataset (QGIS → PostGIS)
- build a routable graph using pgRouting
- run Dijkstra-based routing on a single connected component
- expose routing via a Flask API
- return GeoJSON routes with distance and time estimation
- customizable routing costs (speed, future multi-criteria)
- database guardrails to ensure graph integrity

---

## Stack

- PostgreSQL + PostGIS + pgRouting — graph storage, topology, routing
- Flask + psycopg2 — HTTP API layer
- Docker Compose — orchestration

> Note: older Compose and pgRouting versions are currently used to keep compatibility with low-spec systems.

---

## Prerequisites

- Docker
- Docker Compose
- A `.env` file (based on `.env.example`)

---


## Quick start

**1. Download required files**

[Download `.env` and `nevers_clean.gpkg` here](https://mega.nz/folder/u1RVmZoJ#nld-LyYyCG1GYW-tYga81w)

Place them at:
- `.env` → project root
- `nevers_clean.gpkg` → `/DATA/clean/`

**2. Build and run**

​```bash
docker compose --profile pipeline up
​```

API available at:  
`http://localhost:${FLASK_PORT}`

---

## API

### Test connection

```bash
curl http://localhost:5000/api/test_db
```

---

### Get a route

```bash
curl "http://localhost:5000/api/route?lat1=46.857&lon1=2.997&lat2=46.860&lon2=3.166"
```

### Success response

```json
{
  "type": "Feature",
  "geometry": { "type": "LineString", "coordinates": [...] },
  "properties": {
    "distance_km": 27.19,
    "estimated_time_min": 108.78,
    "speed_kmh": 15
  }
}
```

### Example error response

```json
{
  "error": "ROUTING:NO_PATH",
  "message": "No path found between the selected points."
}
```

---

## Data source


Road network extracted from OpenStreetMap (Nevers + 15 km).

Data has been cleaned and pre-processed in QGIS  
(see [`documentation/data_quality.md`](./documentation/data_quality.md) for full details).

Only the main connected component is used in the current prototype.

---

## Architecture

```
QGIS (data preparation)Checks
      ↓
PostgreSQL / pgRouting (graph + routing)
      ↓
Flask API (HTTP layer)
```

Full pipeline → [`documentation/pipeline.md`](./documentation/pipeline.md)  
Docker setup → [`documentation/docker.md`](./documentation/docker.md)  
Data quality → [`documentation/data_quality.md`](./documentation/data_quality.md) 

---

## Known limitations & roadmap

### WIP — not yet implemented

- engine_functions.md — routing functions documentation
- graph guardrail test suite
- routing functions: add pre/post-processing bounding boxes
- harmonize .env file
- caching
- minimal frontend (Leaflet + Nginx service)
- reduce pipeline verbosity

---

### V2 — planned

- performance audit (cold/warm cache, EXPLAIN ANALYZE)
- automated testing (pytest + API integration)
- multi-criteria costs (surface, lighting, cycleways)
- abstraction layer (support tables beyond routes_v1)
- SRID portability tests (e.g. non-French datasets)
- production-ready deployment (security, pooling)
- upgrade to newer Compose + pgRouting versions

---

### V3 — vision

(honestly this should be called "all these feature creeps that one day are going to kill me but strangely didn't yet")

- automated connected component merging
- isochrone / isometric services
- multi-profile routing (different bike users)
- multimodal routing (bike + other transport modes)
- admin pipeline wizard (frontend)
- user features (gamification, route feedback, usage data)

---

## License

MIT (to be defined)
