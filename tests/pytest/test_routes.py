# [EXPECTED_ERROR] missing parameters -> 400
def test_route_missing_parameters(client):
    response = client.get("/api/route?lat_start=46.86&lon_start=3.16&lat_end=47.11&lon_end=3.26")
    assert response.status_code == 400

# [EXPECTED_ERROR] identical start/end points -> 400
def test_route_same_point(client):
    response = client.get("/api/route?lat_start=46.9862051&lon_start=3.1886892&lat_end=46.9862051&lon_end=3.1886892&speed_kmh=15")
    assert response.status_code == 400

# [EXPECTED_SUCCESS] short route -> 200 GeoJSON Feature with distance_km
def test_small_route(client):
    response = client.get("/api/route?lat_start=46.9862051&lon_start=3.1886892&lat_end=46.9877475&lon_end=3.1656185&speed_kmh=15")
    data = response.get_json()
    assert response.status_code == 200
    assert data["type"] == "Feature"
    assert "geometry" in data
    assert "properties" in data
    assert "distance_km" in data["properties"]
    assert 2 < data["properties"]["distance_km"] < 3

# [EXPECTED_ERROR] out of coverage zone (Paris) -> 422
def test_no_route_out_of_bounds(client):
    response = client.get("/api/route?lat_start=48.827867&lon_start=2.326583&lat_end=48.876789&lon_end=2.359446&speed_kmh=15")
    assert response.status_code == 422

# [EXPECTED_SUCCESS] coverage bbox -> 200 GeoJSON Polygon
def test_api_coverage(client):
    response = client.get("/api/coverage")
    data = response.get_json()
    assert response.status_code == 200
    assert data["type"] == "Polygon"
    assert "coordinates" in data