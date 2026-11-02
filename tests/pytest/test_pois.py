# test_pois.py — integration tests for /api/pois_search
# Layer : Tests (Flask test client + ephemeral Docker stack, see conftest.py)
# Data-dependent: coordinates and expected results assume the Nevers dataset.


VALID_POI = {
    "lat_start": 46.9862051,
    "lon_start": 3.1886892,
    "lat_end": 46.9877475,
    "lon_end": 3.1656185,
    "category": "catering",
    "radius_m": 200,
}


# [EXPECTED_ERROR] missing parameters -> 400
def test_pois_missing_parameters(client):
    params = {k: v for k, v in VALID_POI.items() if k != "category"}
    response = client.get("/api/pois_search", query_string=params)
    assert response.status_code == 400


# [EXPECTED_ERROR] invalid category ("zombie") -> 400
def test_pois_invalid_category(client):
    invalid_category = {
        **VALID_POI,
        "category": "zombie"
    }
    response = client.get("/api/pois_search", query_string=invalid_category)
    assert response.status_code == 400


# [EXPECTED_ERROR] radius below lower bound (10) -> 400
def test_pois_radius_too_small(client):
    invalid_small_radius = {
        **VALID_POI,
        "radius_m": 5
    }
    response = client.get("/api/pois_search", query_string=invalid_small_radius)
    assert response.status_code == 400


# [EXPECTED_ERROR] radius above upper bound (1000) -> 400
def test_pois_radius_too_large(client):
    invalid_high_radius = {
        **VALID_POI,
        "radius_m": 2000
    }
    response = client.get("/api/pois_search", query_string=invalid_high_radius)
    assert response.status_code == 400


# [EXPECTED_ERROR] point out of coverage (Paris) -> 422
def test_pois_out_of_bounds(client):
    paris = {
        "lat_start": 48.827867, "lon_start": 2.326583,
        "lat_end": 48.876789, "lon_end": 2.359446,
        "category": "catering",
        "radius_m": 200
    }
    response = client.get("/api/pois_search", query_string=paris)
    assert response.status_code == 422


# [EXPECTED_ERROR] NaN coordinate -> 400
def test_pois_nan_coordinate(client):
    response = client.get("/api/pois_search", query_string={**VALID_POI, "lat_start": "nan"})
    assert response.status_code == 400
    assert "lat_start" in response.get_json()["message"]


# [EXPECTED_ERROR] identical start/end points -> 400
def test_pois_same_point(client):
    same_point = {
        **VALID_POI,
        "lat_end": VALID_POI["lat_start"],
        "lon_end": VALID_POI["lon_start"]
    }
    response = client.get("/api/pois_search", query_string=same_point)
    assert response.status_code == 400
    assert "differ" in response.get_json()["message"]


# [EXPECTED_SUCCESS] valid search -> 200 GeoJSON FeatureCollection with catering POIs
def test_pois_valid_search(client):
    response = client.get("/api/pois_search", query_string=VALID_POI)
    data = response.get_json()
    assert response.status_code == 200
    assert data["type"] == "FeatureCollection"
    assert "features" in data
    assert len(data["features"]) > 0
    assert "osm_id" in data["features"][0]["properties"]
