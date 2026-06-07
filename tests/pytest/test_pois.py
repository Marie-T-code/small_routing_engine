# tests/pytest/test_pois.py

# [EXPECTED_ERROR] missing parameters -> 400
def test_pois_missing_parameters(client):
    response = client.get("/api/pois_search?lat_start=46.9862051&lon_start=3.1886892&lat_end=46.9877475&lon_end=3.1656185")
    assert response.status_code == 400

# [EXPECTED_ERROR] invalid category ("zombie") -> 400
def test_pois_invalid_category(client):
    response = client.get("/api/pois_search?lat_start=46.9862051&lon_start=3.1886892&lat_end=46.9877475&lon_end=3.1656185&category=zombie&radius_m=200")
    assert response.status_code == 400

# [EXPECTED_ERROR] radius below lower bound (10) -> 400
def test_pois_radius_too_small(client):
    response = client.get("/api/pois_search?lat_start=46.9862051&lon_start=3.1886892&lat_end=46.9877475&lon_end=3.1656185&category=catering&radius_m=5")
    assert response.status_code == 400

# [EXPECTED_ERROR] radius above upper bound (1000) -> 400
def test_pois_radius_too_large(client):
    response = client.get("/api/pois_search?lat_start=46.9862051&lon_start=3.1886892&lat_end=46.9877475&lon_end=3.1656185&category=catering&radius_m=2000")
    assert response.status_code == 400

    # [EXPECTED_ERROR] point out of coverage (Paris) -> 422
def test_pois_out_of_bounds(client):
    response = client.get("/api/pois_search?lat_start=48.8567&lon_start=2.3508&lat_end=48.8600&lon_end=2.3530&category=catering&radius_m=200")
    assert response.status_code == 422

# [EXPECTED_ERROR] identical start/end points -> 400
def test_pois_same_point(client):
    response = client.get("/api/pois_search?lat_start=46.9862051&lon_start=3.1886892&lat_end=46.9862051&lon_end=3.1886892&category=catering&radius_m=200")
    assert response.status_code == 400

# [EXPECTED_SUCCESS] valid search -> 200 GeoJSON FeatureCollection with catering POIs
def test_pois_valid_search(client):
    response = client.get("/api/pois_search?lat_start=46.9862051&lon_start=3.1886892&lat_end=46.9877475&lon_end=3.1656185&category=catering&radius_m=200")
    data = response.get_json()
    assert response.status_code == 200
    assert data["type"] == "FeatureCollection"
    assert "features" in data
    assert len(data["features"]) > 0 