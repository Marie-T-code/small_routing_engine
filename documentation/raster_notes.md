# raster notes

**CRS loss with ASCII Grid sources**
The ASCII Grid format (`.asc`) does not carry the CRS in the file itself. GDAL does not infer one, and silently propagates the absence through `.vrt` and `gdalwarp`. The output is spatially correct (georeferencing, origin, pixel size all valid) but has no declared SRS — it displays fine in QGIS if you force the CRS manually, yet breaks downstream operations.
Symptom: `gdalwarp -cutline` fails with `Cannot compute bounding box of cutline. Cannot find source SRS.`. Here, "cannot compute bounding box of cutline" is the failed operation; "cannot find source SRS" is the reason. The missing SRS is on the **input rasters**, not the cutline.
Fix: `gdal_edit.py -a_srs EPSG:2154 <file>.tif` (assigns the CRS without touching pixels or georeferencing).
Lesson: when starting from `.asc`, declare the CRS explicitly (`-a_srs or -t_srs`) and verify it at each pipeline step — never assume it propagates.

**DEM output format: Int16 over Float32**
Compared a 64 MB Float32 GeoTIFF against a 4.9 MB Int16 version of the same clipped mosaic. Rounding elevations to the metre caused no meaningful loss: min/max/mean/stddev are equivalent (115.8→116, 383→383, mean drift < 0.01 m), and `STATISTICS_VALID_PERCENT` is identical at 75.72% — no pixels lost. Since slope is computed as an average per edge over 20–100 m segments, decimetre precision brings no benefit at this scale.
Chose Int16 for the prototype: 14× lighter, comfortably versionable in Git.
Note: NoData was clamped from -99999 to -32768 (out of Int16 range) — downstream slope computation must use the new value.