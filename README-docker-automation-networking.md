# Why the Grafana Automation Runs Inside Docker

This document explains why the Grafana automation script (`publish_grafana_edges.py`) is executed inside a Docker container attached to the same Docker network as the central stack, rather than running directly on the host system.

This decision was driven by network reachability, name resolution, and TLS correctness.

---

## The Core Problem: Name Resolution

The automation script communicates directly with internal services:

- Grafana HTTP API
- Mimir Prometheus-compatible API

Inside Docker, these services are addressed using Docker DNS names:

- https://grafana:3000
- https://mimir:9009

These hostnames only exist inside the Docker network. When the script was executed on the host, these names were unreachable and resulted in name resolution failures.

---

## Why Running on the Host Failed

From the host system:

- Docker service names are not resolvable
- Docker’s internal DNS is not available
- TLS certificates were issued for Docker service names, not localhost

Even when ports were exposed, TLS validation failed because the hostname used by the client did not match the certificate subject.

---

## Why Running Inside Docker Works

The automation script is executed inside a Docker container attached to the same network as the central services.

This ensures:

- Docker DNS resolves internal service names correctly
- TLS hostname validation succeeds
- Internal URLs remain consistent
- No host-level networking workarounds are required

Example:

```bash
docker run --rm --network mononet grafana-edge-publisher
```

---

## Why This Matters for Automation

The script performs privileged API operations such as:

- Creating Grafana folders
- Creating data sources
- Applying mTLS configuration
- Uploading dashboards

These operations require stable service addressing and correct TLS behavior, which are guaranteed inside the Docker network.

---

## Architectural Justification

Running the automation inside Docker:

- Avoids exposing internal APIs
- Eliminates DNS and TLS mismatches
- Produces consistent, reproducible behavior
- Mirrors how automation jobs would run in production environments

This is an intentional architectural choice, not a workaround.

---

## Summary

The Grafana automation runs inside a Docker container on the same network as the central stack to ensure reliable service discovery and TLS validation. Docker service names such as grafana and mimir are only resolvable within the Docker network, and the certificates are issued for those names. Running the automation inside Docker avoids host-level networking issues and ensures predictable behavior.
