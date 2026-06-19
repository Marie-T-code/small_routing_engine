// map.js — minimal demo front
// Responsibility: show a map, capture 2 clicks (A then B),
// query /api/route, and draw the returned GeoJSON.

const NEVERS = [46.9896, 3.1591];
const DEFAULT_SPEED_KMH = 15;
const map = L.map("map").setView(NEVERS, 14); 

L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
    maxZoom: 19, 
    attribution: "&copy; OpenStreetMap contributors",
}).addTo(map);

// -- click state ---

let start = null;
let markerA = null;
let markerB = null;
let routeLayer = null;

const info = document.getElementById("info");


// -- click handler -- 

map.on("click", (e) => {
    // 3rd click (a route is already drawn) -> reset and start over.
    if (start && routeLayer) {
        resetCycle();
    }

    if (!start) {
        // 1st click -> point A
        start = e.latlng;
        markerA = L.marker(start).addTo(map).bindPopup("Start").openPopup();
        info.textContent = "Click your destination (2/2)";
    } else {
        // 2nd click -> point B, then query
        const end = e.latlng;
        markerB = L.marker(end).addTo(map).bindPopup("End").openPopup();
        drawRoute(start, end);
    }
});

// --- reset route 

function resetCycle(){
    if (markerA) { map.removeLayer(markerA); markerA = null; }
    if (markerB) { map.removeLayer(markerB); markerB = null; }
    if (routeLayer) { map.removeLayer(routeLayer); routeLayer=null;}
    start = null;
    info.textContent = "Click your starting point (1/2)";
}

// --- API call + draw --



async function drawRoute(a, b) {
    const url = 
        `/api/route?lat1=${a.lat}&lon1=${a.lng}` +
        `&lat2=${b.lat}&lon2=${b.lng}`+
        `&speed_kmh=${DEFAULT_SPEED_KMH}`;
    info.textContent = "Computing route..."

    try {
        const response = await fetch(url);
        const data = await response.json();

        if (!response.ok) {
            // Error path: API returned 4xx/5xx with a JSON error body.
            info.textContent = "Error: " + (data.message || response.status);
            return;
        }
        // data is a GeoJSON Feature (geometry in lon/lat, EPSG:4326).
        // L.geoJSON handles the lon/lat -> lat/lng swap on its own.
        routeLayer = L.geoJSON(data, {
            style: { color: "#2563eb", weight: 5, opacity: 0.8 },
        }).addTo(map);

        map.fitBounds(routeLayer.getBounds(), { padding: [40, 40] });

        const p = data.properties || {};
        info.textContent = 
            `${p.distance_km?.toFixed(2)} km · ~${p.estimated_time_min?.toFixed(0)} min`;
    } catch (err) {
        info.textContent = "Network error - is the API up ?";
    }
}