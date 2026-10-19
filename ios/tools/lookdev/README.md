# Toy-city look dev

1. `python3 ios/tools/bake_city.py ios/tools/osm/altstadt.json <out>` (needs trimesh, shapely, mapbox_earcut, pillow)
2. Convert GLBs to embedded glTF JSON (pygltflib) as `*.gltf.json`, copy `index.html` + tree models next to them.
3. `node shoot.js <roemer|river|dom|top> out.png` renders a still headlessly.

Map data © OpenStreetMap contributors (ODbL).
