#!/bin/zsh
# Roads, traffic signals, street lamps and building outlines for central Frankfurt (OSM, ODbL).
# Writes osm/streets.json and osm/buildings.json next to this script. Run on a machine with Overpass access.
cd "$(dirname "$0")/osm"
BBOX="50.092,8.640,50.132,8.720"
q_streets="[out:json][timeout:180];(way[\"highway\"~\"^(motorway|trunk|primary|secondary|tertiary|unclassified|residential|living_street|pedestrian|motorway_link|trunk_link|primary_link|secondary_link|tertiary_link)$\"]($BBOX);node[\"highway\"=\"traffic_signals\"]($BBOX);node[\"highway\"=\"street_lamp\"]($BBOX););out geom;"
q_buildings="[out:json][timeout:180];way[\"building\"]($BBOX);out geom;"
for name in streets buildings; do
  eval q=\$q_$name
  for i in 1 2 3 4 5 6; do
    for host in overpass-api.de overpass.kumi.systems; do
      curl -s -m 200 -A 'SpotsPrototype/0.1' "https://$host/api/interpreter" --data-urlencode "data=$q" -o $name.json
      if grep -q '"elements"' $name.json && ! grep -q 'remark.*runtime error' $name.json; then echo "$name ok from $host"; break 2; fi
    done
    sleep $((i*10))
  done
done
