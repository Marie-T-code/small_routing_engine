# tests/pytest/test_routes.py

def test_route_missing_parameters(client):
    response = client.get("/api/route?lat1=46.86&lon1=3.16&lat2=47.11&lon2=3.26")
    assert response.status_code == 400