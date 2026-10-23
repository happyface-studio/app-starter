#!/bin/zsh
# Residential blocks, gardens, allotments and car parks for central Frankfurt (OSM, ODbL).
# Writes osm/ground.json next to this script. Run on a machine with Overpass access.
cd "$(dirname "$0")/osm"
BBOX="50.092,8.640,50.132,8.720"
q="[out:json][timeout:180];(
wr[\"landuse\"~\"^(residential|allotments|grass|meadow|village_green|commercial|retail)$\"]($BBOX);
wr[\"leisure\"~\"^(garden|playground)$\"]($BBOX);
wr[\"amenity\"=\"parking\"][\"parking\"!~\"underground|multi-storey\"]($BBOX);
);out geom;"
for i in 1 2 3 4 5 6; do
  for host in overpass-api.de overpass.kumi.systems; do
    curl -s -m 200 -A 'SpotsPrototype/0.1' "https://$host/api/interpreter" --data-urlencode "data=$q" -o ground.json
    if grep -q '"elements"' ground.json && ! grep -q 'remark.*runtime error' ground.json; then echo "ground ok from $host"; exit 0; fi
  done
  sleep $((i*10))
done
echo "ground FAILED"
