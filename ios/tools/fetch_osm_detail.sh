#!/bin/zsh
# Shops, cafés, bars and restaurants, benches and bike parking for central Frankfurt (OSM, ODbL).
# Writes osm/detail.json next to this script. Run on a machine with Overpass access.
cd "$(dirname "$0")/osm"
BBOX="50.092,8.640,50.132,8.720"
q="[out:json][timeout:180];(
nwr[\"shop\"]($BBOX);
nwr[\"amenity\"~\"^(cafe|restaurant|bar|pub|fast_food|ice_cream|biergarten|pharmacy|bank)$\"]($BBOX);
node[\"amenity\"~\"^(bench|bicycle_parking|bicycle_rental)$\"]($BBOX);
);out center tags;"
for i in 1 2 3 4 5 6; do
  for host in overpass-api.de overpass.kumi.systems; do
    curl -s -m 200 -A 'SpotsPrototype/0.1' "https://$host/api/interpreter" --data-urlencode "data=$q" -o detail.json
    if grep -q '"elements"' detail.json && ! grep -q 'remark.*runtime error' detail.json; then echo "detail ok from $host"; exit 0; fi
  done
  sleep $((i*10))
done
echo "detail FAILED"
