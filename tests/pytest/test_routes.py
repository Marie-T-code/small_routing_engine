# tests/pytest/test_routes.py

def test_route_missing_parameters(client):
    response = client.get("/api/route?lat1=46.86&lon1=3.16&lat2=47.11&lon2=3.26")
    assert response.status_code == 400

def test_small_route(client):
    response = client.get("/api/route?lat1=46.9862051&lon1=3.1886892&lat2=46.9877475&lon2=3.1656185&speed_kmh=15")
    data = response.get_json()
    assert response.status_code == 200
    assert data["type"] == "Feature"
    assert "geometry" in data
    assert "properties" in data
    assert "distance_km" in data["properties"]
    assert 2 < data["properties"]["distance_km"] < 3

def test_no_route(client):
    response = client.get("/api/route?lat1=46.9868901&lon1=3.1697954&lat2=46.9868901&lon2=3.1697954&speed_kmh=15")
    assert response.status_code == 404

def test_no_route_out_of_bounds(client):
    response = client.get("/api/route?lat1=48.827867&lon1=2.326583&lat2=48.876789&lon2=2.359446&speed_kmh=15")
    assert response.status_code ==422

def test_api_coverage(client):
    response = client.get("/api/coverage")
    data = response.get_json()
    assert response.status_code == 200
    assert data["type"] == "Polygon"
    assert "coordinates" in data