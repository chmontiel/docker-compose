# Edge Stack Configuration

Each edge environment is designed to be repeatable, lightweight, and disposable. All edge stacks follow the same structure, with differences limited to service names, ports, tenant IDs, and certificates.

An edge stack consists of:
- Demo web applications that generate metrics
- A single Prometheus instance per edge
- A Blackbox exporter for active probing
- Secure remote_write to the central Mimir instance

---

## 1. edge-*/docker-compose.yml

Each edge uses its own Docker Compose file to define local services.

### Components

- Demo web applications  
  Used to generate scrape-able HTTP metrics. Each app is exposed on a unique host port to avoid conflicts.

- Prometheus  
  One instance per edge, named after the tenant (for example, p1, p2). Responsible for scraping local services and forwarding metrics to Mimir.

- Blackbox exporter  
  Performs active HTTP probing of services. Kept separate from Prometheus to simplify configuration and reuse.

### Example

```yaml
webapp-a1:
  build: ./webapp
  ports:
    - "8081:8080"

p1:
  image: prom/prometheus:latest
  volumes:
    - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
    - prom_data:/prometheus
    - ./certs:/etc/prometheus/certs:ro
  ports:
    - "9091:9090"

blackbox-edge-a:
  image: prom/blackbox-exporter:latest
  ports:
    - "9116:9115"
  volumes:
    - ./blackbox/blackbox.yml:/etc/blackbox_exporter/blackbox.yml:ro
```

### Common Pitfalls

- Internal ports must remain fixed  
  Web apps always listen on 8080, Prometheus on 9090, and Blackbox exporter on 9115. Only host ports should change.

- Certificate paths must match Prometheus configuration  
  Prometheus expects certificates at /etc/prometheus/certs. If paths do not align, TLS authentication will fail.

---

## 2. edge-*/prometheus.yml

This file defines how each edge scrapes services, labels metrics, probes endpoints, and securely pushes data to the central Mimir instance.

---

### a. Edge Identification via Labels

```yaml
global:
  external_labels:
    site: edge-a
```

The site label uniquely identifies the edge. Dashboards and queries rely on this label to distinguish metrics from different environments.

Common issue: reusing the same site label across edges makes queries ambiguous.

---

### b. Scraping Web Applications via Docker DNS

```yaml
- job_name: "webapps"
  static_configs:
    - targets:
        - "webapp-a1:8080"
        - "webapp-a2:8080"
```

Targets are referenced using Docker service names, not localhost. Docker’s internal DNS resolves these names automatically.

---

### c. Blackbox Exporter Probing

```yaml
- job_name: 'blackbox-edge-a'
  metrics_path: /probe
  params:
    module: [http_2xx]
  static_configs:
    - targets:
        - http://webapp-a1:8080
  relabel_configs:
    - source_labels: [__address__]
      target_label: __param_target
    - source_labels: [__param_target]
      target_label: instance
    - target_label: __address__
      replacement: blackbox-edge-a:9115
```

This relabeling pattern forwards targets to the Blackbox exporter and produces clean instance labels for dashboards.

---

### d. remote_write to Central Mimir

```yaml
remote_write:
  - url: "https://mimir:9009/api/v1/push"
    headers:
      X-Scope-OrgID: "p1"
    tls_config:
      ca_file: /etc/prometheus/certs/ca.crt
      cert_file: /etc/prometheus/certs/edge-a.crt
      key_file: /etc/prometheus/certs/edge-a.key
      server_name: mimir
```

Key details people often miss:

- X-Scope-OrgID enforces tenant isolation in Mimir. Each edge must use a unique tenant ID.
- server_name must match a Subject Alternative Name on the Mimir server certificate.
- The client certificate must be signed by the same CA trusted by Mimir.

If any of these are misconfigured, metric ingestion will fail.

---

## Summary

The edge stack configuration is intentionally uniform across environments. Most issues when adding new edges are caused by:

- Inconsistent internal ports
- Missing or duplicated labels
- Incorrect certificate paths
- TLS SAN mismatches

Keeping edge configurations consistent ensures that new environments can be added safely, automation works correctly, and metrics remain isolated and queryable.
