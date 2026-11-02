# test_routes.py — integration tests for /api/route and /api/coverage
# Layer : Tests (Flask test client + ephemeral Docker stack, see conftest.py)
# Data-dependent: coordinates and expected distances assume the Nevers graph.


# A valid request; each error test changes only the parameter under test
VALID_ROUTE = {
    "lat_start": 46.9862051,
    "lon_start": 3.1886892,
    "lat_end": 46.9877475,
    "lon_end": 3.1656185,
    "speed_kmh": 15,
}


# [EXPECTED_ERROR] missing parameters -> 400
def test_route_missing_parameters(client):
    params = {k: v for k, v in VALID_ROUTE.items() if k != "speed_kmh"}
    response = client.get("/api/route", query_string=params)
    assert response.status_code == 400


# [EXPECTED_ERROR] NaN coordinate -> 400
def test_route_nan_coordinate(client):
    response = client.get("/api/route", query_string={**VALID_ROUTE, "lat_start": "nan"})
    assert response.status_code == 400
    assert "lat_start" in response.get_json()["message"]


# [EXPECTED_ERROR] identical start/end points -> 400
def test_route_same_point(client):
    same_point = {
        **VALID_ROUTE,
        "lat_end": VALID_ROUTE["lat_start"],
        "lon_end": VALID_ROUTE["lon_start"],
    }
    response = client.get("/api/route", query_string=same_point)
    assert response.status_code == 400
    assert "differ" in response.get_json()["message"]


# [EXPECTED_SUCCESS] short route -> 200 GeoJSON Feature with distance_km
def test_small_route(client):
    response = client.get("/api/route", query_string=VALID_ROUTE)
    data = response.get_json()
    assert response.status_code == 200
    assert data["type"] == "Feature"
    assert "geometry" in data
    assert "properties" in data
    assert "distance_km" in data["properties"]
    assert 2 < data["properties"]["distance_km"] < 3


# [EXPECTED_ERROR] out of coverage zone (Paris) -> 422
def test_no_route_out_of_bounds(client):
    paris = {
        "lat_start": 48.827867, "lon_start": 2.326583,
        "lat_end": 48.876789, "lon_end": 2.359446,
        "speed_kmh": 15,
    }
    response = client.get("/api/route", query_string=paris)
    assert response.status_code == 422


# [EXPECTED_SUCCESS] coverage bbox -> 200 GeoJSON Polygon
def test_api_coverage(client):
    response = client.get("/api/coverage")
    data = response.get_json()
    assert response.status_code == 200
    assert data["type"] == "Polygon"
    assert "coordinates" in data
