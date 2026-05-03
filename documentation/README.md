# Documentation

This folder contains the project's technical documentation. Each file
covers one specific aspect; the categories below help you find the
right entry point.

## Start here

If you are new to the project and want to understand how data flows
end-to-end, from OpenStreetMap to the API:

- [`pipeline.md`](./pipeline.md) — full ETL pipeline, design principles,
  runtime flow

## Reference

Technical references on the database and the SQL code:

- [`data_model.md`](./data_model.md) — tables, views, indexes, SRID
  strategy, configuration functions
- [`architecture.md`](./architecture.md) — SQL directory layout, master
  orchestration, function dependency chain
- [`engine_functions.md`](./engine_functions.md) — PL/pgSQL function
  catalogue
- [`error_codes_sre.md`](./error_codes_sre.md) — structured error tags
  raised by guardrails and routing functions

## Operations

How to run and troubleshoot the project:

- [`docker.md`](./docker.md) — services, profiles, network
  troubleshooting

## Concepts

The "why" behind the technical choices:

- [`data_quality.md`](./data_quality.md) — quality choices, observed
  limits, what comes next
- [`graph_build.md`](./graph_build.md) — how `pgr_createTopology()`
  builds a routable graph (and the idempotence pitfall)
