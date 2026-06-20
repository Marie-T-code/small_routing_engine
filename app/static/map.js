// map.js — minimal demo front
// Responsibility: show a map, capture 2 clicks (A then B),
// query /api/route, and draw the returned GeoJSON.

const NEVERS = [46.9896, 3.1591];
const DEFAULT_SPEED_KMH = 15;
const POI_RADIUS_M = 500;
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
let currentRoute = null;
let poiLayers = {};

const info = document.getElementById("info");
const poiPanel = document.getElementById("poi-panel");

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
    currentRoute = null;
    poiPanel.classList.add("hidden");
    // remove all POI layers and reset button states
    for (const cat in poiLayers) {
        map.removeLayer(poiLayers[cat]);
    }
    poiLayers = {};
    document.querySelectorAll(".poi-btn").forEach((b) => b.classList.remove("active"));
    start = null;
    info.textContent = "Click your starting point (1/2)";
}

// --- POI toggle ----
// attach the same handler to all category buttons (DRY). 
// Each button knows its catagory via data-category -> dataset.category.

document.querySelectorAll(".poi-btn").forEach((btn) => {
    btn.addEventListener("click", () =>{
        const category = btn.dataset.category;
        if(poiLayers[category]) {
            //already shown -> toggle off
            map.removeLayer(poiLayers[category]);
            delete poiLayers[category];
            btn.classList.remove("active");
        } else {
            // not shown -> toggle ON(fetch = draw)
            loadPois(category, btn);
        }
    });

});

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
        currentRoute = {a, b};
        poiPanel.classList.remove("hidden");

        map.fitBounds(routeLayer.getBounds(), { padding: [40, 40] });

        const p = data.properties || {};
        info.textContent = 
            `${p.distance_km?.toFixed(2)} km · ~${p.estimated_time_min?.toFixed(0)} min`;
    } catch (err) {
        info.textContent = "Network error - is the API up ?";
    }
}

// --- POI fetch + draw

async function loadPois(category, btn) {
    // Guard: POI search needs an existing route (corridor along the path).
    if (!currentRoute) return;

    const { a, b } = currentRoute;
    const url = 
    `/api/pois_search?lat_start=${a.lat}&lon_start=${a.lng}` +
    `&lat_end=${b.lat}&lon_end=${b.lng}` +
    `&category=${category}&radius_m=${POI_RADIUS_M}`;

    try {
        const response = await fetch(url);
        const data = await response.json();

        if (!response.ok) {
            info.textContent = "POI error: " + (data.message || response.status);
            return;
        }

        // data is a GeoJSON FeatureCollection (points in lon/lat EPSG:4326).
        const layer = L.geoJSON(data, {
            pointToLayer: (feature, latlng) => L.circleMarker(latlng, {
                radius: 6, color : "#dc2626", fillColor: "#dc2626", fillOpacity: 0.8,
            }),
            onEachFeature: (feature, lyr) => {
                const p = feature.properties || {};
                lyr.bindPopup(`<b>${p.name || "Unnamed"}</b><br>${p.amenity || ""}`);
            },
        }).addTo(map);

        poiLayers[category] = layer;
        btn.classList.add("active");
    } catch (err) {
        info.textContent = "Network error — is the API up?";
    }
}