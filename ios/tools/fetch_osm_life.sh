#!/bin/zsh
# Footpaths, tram tracks and stops, the river Main and fountains for central Frankfurt (OSM, ODbL).
# Writes osm/life.json next to this script. Run on a machine with Overpass access.
cd "$(dirname "$0")/osm"
BBOX="50.092,8.640,50.132,8.720"
q="[out:json][timeout:180];(
way[\"highway\"~\"^(footway|pedestrian|path|steps|living_street)$\"]($BBOX);
way[\"railway\"=\"tram\"]($BBOX);
node[\"railway\"=\"tram_stop\"]($BBOX);
node[\"public_transport\"=\"stop_position\"][\"tram\"=\"yes\"]($BBOX);
way[\"waterway\"=\"river\"](50.085,8.60,50.125,8.76);
node[\"amenity\"=\"fountain\"]($BBOX);
);out geom;"
for i in 1 2 3 4 5 6; do
  for host in overpass-api.de overpass.kumi.systems; do
    curl -s -m 200 -A 'SpotsPrototype/0.1' "https://$host/api/interpreter" --data-urlencode "data=$q" -o life.json
    if grep -q '"elements"' life.json && ! grep -q 'remark.*runtime error' life.json; then echo "life ok from $host"; exit 0; fi
  done
  sleep $((i*10))
done
echo "life FAILED"
