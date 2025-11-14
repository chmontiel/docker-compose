```bash
export GRAFANA_URL="https://grafana.localhost"
export GRAFANA_TOKEN="gf_sa_xxx"
export MIMIR_URL="https://mimir:9009/prometheus"
export FOLDER_TITLE="Edges"
export FOLDER_UID="edges-folder"
export TEMPLATE_PATH="central/grafana/dashboards/edge-template.json"
export DATASOURCE_PREFIX="Mimir - "

EDGE=edge-c python3 tools/publish_grafana_edges.py


```

```powershell
$env:GRAFANA_URL      = "https://grafana.localhost"
$env:GRAFANA_TOKEN    = "gf_sa_xxx"
$env:MIMIR_URL        = "https://mimir.localhost/prometheus"  # <-- through Caddy
$env:TEMPLATE_PATH    = "central/grafana/dashboards/edge-template.json"
$env:DATASOURCE_PREFIX = "Mimir - "
$env:FOLDER_TITLE     = "Edges"
$env:FOLDER_UID       = "edges-folder"
$env:EDGE             = "edge-c"

python3 tools/publish_grafana_edges.py


```