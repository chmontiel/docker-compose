# 🐳 Docker Compose: Prometheus & Grafana Setup

This README explains how Docker Compose manages multiple containers, how container communication works, how to persist and automatically provision Grafana dashboards, and how to run, view logs, and troubleshoot target discovery.

---

## ⚙️ What is Docker Compose?

Docker Compose is **not a container**—it’s a **tool** that:
- Reads your `docker-compose.yml` configuration file.
- Starts multiple containers (called *services*).
- Connects them together on a shared **virtual network**.
- Manages their lifecycle as one project.

When you run:
```bash
docker compose up -d
```
Compose:
1. Creates the defined network(s) (e.g., `monitoring`).
2. Starts all containers (Prometheus, Grafana, etc.).
3. Connects them automatically so they can communicate by **service name**.

---

## 🚀 Command: `docker compose up -d`

### Breakdown:
- `docker compose` → The command-line interface for Docker Compose.
- `up` → Builds, (re)creates, starts, and attaches containers defined in the compose file.
- `-d` → **Detached mode** — runs everything in the background so you can continue using your terminal.

### Examples
```bash
docker compose up -d  # starts all containers in background
docker compose down   # stops and removes containers
docker compose ps     # shows running containers
docker compose logs   # displays logs
```

---

## 🧩 How Docker Compose Works Internally

```
┌────────────────────────────────────────────┐
│   Your Computer (Docker Engine running)    │
│                                            │
│  ┌─────────────── monitoring ─────────────┐ │
│  │                                         │
│  │  (Docker user-defined network)          │
│  │                                         │
│  │  ┌──────────────┐       ┌──────────────┐ │
│  │  │  Prometheus  │◄────►│   Grafana    │ │
│  │  │ Hostname:    │       │ Hostname:    │ │
│  │  │ prometheus   │       │ grafana      │ │
│  │  │ Port: 9090   │       │ Port: 3000   │ │
│  │  └──────────────┘       └──────────────┘ │
│  │                                         │
│  └─────────────────────────────────────────┘
│                                            │
└────────────────────────────────────────────┘
```

Both containers share a **virtual network** named `monitoring`, allowing them to communicate internally by **name** (`prometheus:9090`). Docker automatically handles the DNS resolution.

---

## 🧱 Example docker-compose.yml

```yaml
services:
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prom_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
    networks: [monitoring]

  grafana:
    image: grafana/grafana-oss:latest
    ports:
      - "3000:3000"
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
      - ./grafana/dashboards:/var/lib/grafana/dashboards
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin
    depends_on: [prometheus]
    networks: [monitoring]

volumes:
  prom_data:
  grafana_data:

networks:
  monitoring:
    driver: bridge
```

---

## 🌐 How Containers Communicate

### Docker Network (Bridge)
The `bridge` network acts as a **virtual switch** connecting containers. Each container gets:
- A unique private IP address.
- A hostname equal to its service name.

Example:
```
Prometheus → 172.20.0.2 (hostname: prometheus)
Grafana    → 172.20.0.3 (hostname: grafana)
```

Grafana can reach Prometheus internally using:
```
http://prometheus:9090
```
Docker resolves `prometheus` → `172.20.0.2` automatically.

---

## ⚙️ The Role of `depends_on`

```yaml
depends_on: [prometheus]
```
This ensures that Prometheus starts **before** Grafana when you run `docker compose up -d`.  
It does **not** wait for Prometheus to be fully ready — for that, you can add a **healthcheck**.

---

## 💾 Persistent Volumes in Docker

A **Docker volume** is a special type of storage that lives **outside** the container’s filesystem, ensuring your data isn’t lost when containers stop or are recreated.

### Why use volumes?
- Containers are temporary — deleting one removes its data.
- Volumes store data **persistently** across container restarts.
- They can be shared between multiple containers.

Example:
```yaml
volumes:
  prom_data:
  grafana_data:
```
These lines define persistent volumes:
- **prom_data** → stores Prometheus time-series database.
- **grafana_data** → stores dashboards, settings, and user data.

To inspect volumes:
```bash
docker volume ls
docker volume inspect grafana_data
```

---

## 📦 Automatically Import Dashboards (Provisioning)

Grafana can automatically import dashboards and data sources at startup — no manual uploading needed.

### Folder structure:
```
grafana/
 └── provisioning/
     ├── dashboards/
     │    └── dashboards.yaml
     └── datasources/
          └── datasource.yaml
 └── dashboards/
     └── my-dashboard.json
```

### dashboards.yaml
```yaml
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    editable: true
    updateIntervalSeconds: 10
    options:
      path: /var/lib/grafana/dashboards
```

### datasource.yaml
```yaml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
```

When Grafana starts, it automatically reads these configs and imports your dashboards from `/var/lib/grafana/dashboards`.

---

## 🧠 Useful Docker Commands

### Docker Compose
| Command | Description |
|----------|--------------|
| `docker compose up -d` | Starts all containers in detached mode. |
| `docker compose down` | Stops and removes all containers. |
| `docker compose ps` | Lists all containers in the Compose project. |
| `docker compose logs` | Displays logs for all containers. |
| `docker compose logs <service>` | Shows logs for one service (e.g., Grafana). |
| `docker compose restart` | Restarts all containers. |
| `docker compose exec <service> sh` | Opens a shell inside a running container. |

### Docker Basics
| Command | Description |
|----------|--------------|
| `docker ps` | Lists running containers. |
| `docker images` | Lists downloaded images. |
| `docker stop <container>` | Stops a container. |
| `docker rm <container>` | Removes a stopped container. |
| `docker volume ls` | Lists persistent volumes. |
| `docker network ls` | Lists all networks. |
| `docker system prune -a` | Cleans unused containers, images, and networks. ⚠️ |

---

## 🗂️ Exporting & Importing Grafana Dashboards (Deliverable)

You’ll submit exported dashboard JSON(s) in this repo. There are **two ways** to export: via **UI** (manual) or **HTTP API** (scriptable). Both are documented here.

### ✅ Method A — Export via Grafana UI (simple)
1. Open your dashboard in Grafana (e.g., http://localhost:3000).
2. Click **Share** (up‑arrow icon) → **Export** tab.
3. Choose **Export to JSON**.
   - Optionally enable **Export for sharing externally** (embeds data‑source references for portability).
4. Save the file into the repo, e.g. `grafana/dashboards/system_overview.json`.

**Import via UI:** Dashboards → **New** → **Import** → Upload JSON → choose Prometheus data source → **Import**.

---

### ⚙️ Method B — Export via API (repeatable / for CI)

> Assumes local Grafana at `http://localhost:3000` and basic auth `admin:admin`. Replace as needed or use an API token.

**Find the dashboard UID:** it’s in the URL `/d/<UID>/...` when the dashboard is open.

**Export one dashboard (curl):**
```bash
curl -u admin:admin \
  http://localhost:3000/api/dashboards/uid/<UID> \
  -o grafana/dashboards/<UID>.json
```

**Export one dashboard (PowerShell):**
```powershell
$uid = "<UID>"
$auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("admin:admin"))
Invoke-WebRequest \
  -Headers @{ Authorization = "Basic $auth" } \
  -Uri "http://localhost:3000/api/dashboards/uid/$uid" \
  -OutFile "grafana/dashboards/$uid.json"
```

**Bulk export all dashboards (PowerShell):**
```powershell
$auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("admin:admin"))
$dashes = Invoke-RestMethod -Headers @{ Authorization = "Basic $auth" } \
  -Uri "http://localhost:3000/api/search?type=dash-db" -Method Get
$dashes | ForEach-Object {
  $uid = $_.uid
  $out = "grafana/dashboards/$uid.json"
  Invoke-WebRequest -Headers @{ Authorization = "Basic $auth" } \
    -Uri "http://localhost:3000/api/dashboards/uid/$uid" -OutFile $out
}
```
> This saves each dashboard’s full JSON to `grafana/dashboards/` so you can commit them.

**Import via API (curl):**
```bash
curl -u admin:admin -H "Content-Type: application/json" \
  -X POST http://localhost:3000/api/dashboards/db \
  -d @grafana/dashboards/<UID>.json
```

---

### 🔁 Auto‑load exported dashboards on startup (provisioning)
If you place exported JSON files under `grafana/dashboards/` and keep the provisioning mounts:
```yaml
  grafana:
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
      - ./grafana/dashboards:/var/lib/grafana/dashboards
```
…and your `dashboards.yaml` points to `/var/lib/grafana/dashboards`, Grafana will **auto‑import** those JSON files on container start.

---

## 🧾 Documentation: Running, Viewing Logs, and Troubleshooting

### Running the Stack
Run your monitoring stack using:
```bash
docker compose up -d
```

**Explanation:**
- `up` → Starts or rebuilds services.
- `-d` → Runs containers in detached (background) mode.

To stop the stack:
```bash
docker compose down
```
To stop and remove volumes:
```bash
docker compose down --volumes
```

---

### Viewing Logs
To view all logs:
```bash
docker compose logs
```
To view logs for a single service:
```bash
docker compose logs prometheus
```
To follow logs live:
```bash
docker compose logs -f grafana
```

**Example output:**
```
grafana  | HTTP Server Listen: http://0.0.0.0:3000/
prometheus | Server is ready to receive web requests.
```

---

### Troubleshooting Target Discovery in Prometheus

If you see:
```
Error scraping target: connect: connection refused
```
It means Prometheus cannot reach a scrape target.

#### Steps to Fix:
1. **Verify exporter is running:**
   ```bash
   docker ps
   ```
2. **Test endpoint manually:**
   ```bash
   docker exec -it <prometheus-container> sh
   wget -qO- http://host.docker.internal:9182/metrics || true
   exit
   ```
3. **Check target config:**
   In `prometheus.yml`:
   ```yaml
   scrape_configs:
     - job_name: 'windows'
       static_configs:
         - targets: ['host.docker.internal:9182']
   ```
4. **Verify in Prometheus UI:**
   Visit: http://localhost:9090/targets
   - Green = Up; Red = Down (connection issue)
5. **Restart Prometheus:**
   ```bash
   docker compose restart prometheus
   ```

#### Common Fixes
| Problem | Solution |
|----------|-----------|
| Grafana connection refused | Use `http://prometheus:9090` as the data source URL |
| Prometheus target down | Check exporter IP or port; firewall; service is running |
| Dashboard not appearing | Verify provisioning folder mount paths |
| Data missing after restart | Ensure volumes (`prom_data`, `grafana_data`) exist |

---

## ✅ TL;DR Summary

| Concept | Description |
|----------|--------------|
| **UI Export** | Share → Export → JSON; commit to `grafana/dashboards/`. |
| **API Export** | `GET /api/dashboards/uid/<UID>` save JSON; script for bulk. |
| **Provisioning** | Auto-load dashboards from `/var/lib/grafana/dashboards`. |
| **Compose Up (-d)** | Start services in background; `down` stops. |
| **Logs** | `docker compose logs [-f] <service>` to debug. |
| **Targets** | Prometheus → `/targets` to check scrape health. |

