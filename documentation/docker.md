# docker orchestration

This section aims to describe : the services and what they are in charge of,which volumes are persistant, how to use the two profiles and to what end, what was the most basic security measure taken. This is a development project, the yml reflects this. Once the project feels satisfying to me, I'll step up to production. 

## docker structure

```
docker compose
├── core services
│   ├── db           (PostGIS/pgRouting database)
│   └── api          (Flask API)
├── pipeline profile
│   ├── loader       (data import)
│   └── builder      (graph build)
└── devtools profile
    └── builder_dev  (manual export / debug service for Linux users)
```

## services roles

Intent : run the whole pipeline ine one command:
``` bash

docker compose --profile pipeline up

```

The core responsibilities have been separated in different services (loader builder) in order for the yml to orchestrate:
- the core services setup
- then the loader imports data
- then the builder runs the SQL logic

Every critical service checks if the one it requires either is up and healthy OR has run and exited with no error signal.

### core services 

Those two services are up with a docker compose up, persistent, and always running. 

1. **db**

this service contains the core engine in SQL. 
It is always up and the database is consistent unless docker compose down -v. 

2. **api**

This service contains the Flask routes that can interrogate the database and serve an itinerary in a (future) frontend. 

### profiles

The profiles help run the pipeline and solve an export problem I encountered as a new Linux user. 

1. **"pipeline" profile**

It contains 2 services: 

a. loader : 

service in charge of importing data into the database. 
Intent : make sure the data loading is done **AFTER** the database is up and healthy

b. builder : "injection of SQL logic" profile : 

Intent : make sure this service runs all necessary MASTER.sql files to setup steps 4-7 of the pipeline (see pipelin.md) **AFTER** the loader has ran and exited with no errors.


2. **"devtools" profile**

You do not need this profile if you are a Windows/Mac user. 

This profile was created for Linux users. Its goal is to **export files from the database with the UID/GID mapped in the .env file**. 
You can code, modify, run files in the db service, but this one uses a Postgres UID/GID. It would not work at all if you wanted to force your UID/GID on it to export files. 

**export commands examples**: 

```bash
docker compose --profile devtools run --rm builder_dev psql -f /path/to/file_to_export.sql (/DEBUG/ will contain files ready to export in geojson)
```
or 
``` bash
docker compose --profile devtools run --rm builder_dev psql  -c "\COPY table_name TO '/exports/results.csv' CSV"
```

## Security is in the .env

The .env file (download link in the [readme.md](../readme.md)) stores the services id and passwords in variables so they don't have to be hardcoded in the yml.

It is never commited to git. 

(Security is the next phase of the project so I took... the most basic of security step possible, I'll get better).