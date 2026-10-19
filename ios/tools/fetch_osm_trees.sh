#!/bin/zsh
q_trees='[out:json][timeout:120];node["natural"="tree"](50.092,8.640,50.132,8.720);out;'
q_green='[out:json][timeout:120];(way["leisure"~"^(park|garden)$"](50.092,8.640,50.132,8.720);way["landuse"~"^(forest|cemetery)$"](50.092,8.640,50.132,8.720);way["natural"="wood"](50.092,8.640,50.132,8.720););out geom;'
for name in trees green; do
  eval q=\$q_$name
  for i in 1 2 3 4 5 6 7 8; do
    for host in overpass-api.de overpass.kumi.systems; do
      curl -s -m 150 -A 'SpotsPrototype/0.1 (contact: simon)' "https://$host/api/interpreter" --data-urlencode "data=$q" -o $name.json
      if grep -q '"elements"' $name.json && ! grep -q 'remark.*runtime error' $name.json; then echo "$name ok from $host"; break 2; fi
    done
    sleep $((i*10))
  done
done
echo DONE > done.txt
