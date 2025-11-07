# 🧠 README: TLS and mTLS Setup for Central Mimir, Edges, and Grafana

---

## 🔍 1️⃣ What TLS and mTLS Actually Are

### **HTTP (plain)**

```
http://host:port
```

* No encryption or identity.
* Anyone on the network can read or modify data.
* OK for local testing; ❌ not secure for production.

---

### **TLS / HTTPS**

```
https://host:port
```

* HTTP wrapped in **Transport Layer Security (TLS)** → encrypted traffic.
* The **server** proves its identity with a certificate.
* The **client** verifies:

  * The cert is valid, signed by a trusted CA, and matches the hostname.
* In this project: edges (Prometheus) → central (Mimir) use HTTPS so metrics aren’t sent in the clear.

---

### **mTLS (Mutual TLS)**

* Regular TLS → server proves who it is.
* **mTLS → both sides authenticate each other** using certificates.
* Mimir runs with `RequireAndVerifyClientCert`, so it accepts only clients that present valid CA-signed certs (Grafana & edges).

---

### **TLS Benefits**

1. **Encryption** – keeps metric data private.
2. **Integrity** – prevents tampering in transit.
3. **Authentication** – ensures you connect to the real service.

### **mTLS Enhancement**

Adds client-side authentication:
Both peers present certificates and verify them against the CA.
→ Only authorized Prometheus edges and Grafana can talk to Mimir.

---

## 🏗️ 2️⃣ Creating a Local Certificate Authority (CA)

The CA is the **root of trust** that signs all service certificates.

### Step 1 – Generate CA Private Key

```bash
openssl genrsa -out ca.key 4096
```

### Step 2 – Generate CA Certificate

```bash
openssl req -x509 -new -key ca.key -sha256 -days 3650   -subj "/CN=MyLocalCA" -out ca.crt
```

### Step 3 – Verify

```bash
openssl x509 -in ca.crt -noout -text
```

✅ Subject and Issuer should both be `MyLocalCA`.

---

## 🔐 3️⃣ Issuing Certificates for Each Service

Each service (Mimir, Edges, Grafana, Caddy) gets its own certificate signed by the CA.
This prevents reuse and allows independent revocation.

### **Central (Mimir)**

```bash
openssl req -new -key central.key -out central.csr -subj "/CN=mimir"
```

`central_ext.cnf`

```ini
subjectAltName = @alt_names
[alt_names]
DNS.1 = mimir
DNS.2 = central
```

Sign it:

```bash
openssl x509 -req -in central.csr -CA ca.crt -CAkey ca.key   -CAcreateserial -out central.crt -days 365 -sha256 -extfile central_ext.cnf
```

---

### **Edges (Prometheus A / B)**

```bash
openssl genrsa -out edge-a.key 2048
openssl req -new -key edge-a.key -out edge-a.csr -subj "/CN=edge-a"
openssl x509 -req -in edge-a.csr -CA ca.crt -CAkey ca.key   -CAcreateserial -out edge-a.crt -days 365 -sha256
```

Repeat for `edge-b`.

---

### **Grafana**

```bash
openssl genrsa -out grafana.key 2048
openssl req -new -key grafana.key -out grafana.csr -subj "/CN=grafana"
openssl x509 -req -in grafana.csr -CA ca.crt -CAkey ca.key   -CAcreateserial -out grafana.crt -days 365 -sha256
```

---

## ⚙️ 4️⃣ Service Configuration with TLS/mTLS

### **Mimir (central/mimir.yml)**

```yaml
server:
  http_listen_port: 9009
  http_tls_config:
    cert_file: /etc/mimir/tls/central.crt
    key_file: /etc/mimir/tls/central.key
    client_auth_type: RequireAndVerifyClientCert
    client_ca_file: /etc/mimir/tls/ca.crt
```

### **Prometheus (edge-a.yml / edge-b.yml)**

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

### **Grafana (provisioning/datasources/mimir.yml)**

```yaml
apiVersion: 1
datasources:
  - name: Mimir - Edge A
    type: prometheus
    access: proxy
    url: https://mimir:9009/prometheus
    jsonData:
      httpHeaderName1: X-Scope-OrgID
      tlsAuth: true
      tlsAuthWithCACert: true
    secureJsonData:
      httpHeaderValue1: p1
      tlsCACert: |
        (ca.crt contents)
      tlsClientCert: |
        (grafana.crt contents)
      tlsClientKey: |
        (grafana.key contents)
```

---

## 🌐 5️⃣ Why We Put Mimir and Grafana Behind a Caddy Reverse Proxy

### **Purpose**

Caddy acts as a **secure HTTPS entry point** for browser and API access, offloading certificate handling and allowing centralized control.

| Without Proxy                                        | With Caddy Proxy                                |
| ---------------------------------------------------- | ----------------------------------------------- |
| Browser → Mimir/Grafana directly on 9009/3000        | Browser → Caddy (443) → Mimir/Grafana           |
| Each service must manage its own HTTPS & cert reload | One central service handles HTTPS               |
| Harder to add access control later                   | Easy to add auth middleware, headers, redirects |

---

### **Why Caddy (not Nginx)**

* **Native TLS and mTLS support** → no manual OpenSSL directives.
* **Auto reloads certs** on file change.
* **Cleaner syntax** for reverse proxy TLS upstreams.
* Perfect for containerized monitoring stacks.

---

### **How It Works**

1. **Browser → Caddy (HTTPS):**

   * Caddy serves HTTPS using `central.crt` / `central.key`.
   * End users see `https://grafana.localhost` and `https://mimir.localhost`.

2. **Caddy → Mimir (mTLS):**

   * Caddy connects to Mimir over HTTPS (`https://mimir:9009`).
   * Presents `grafana.crt` as its client certificate.
   * Validated against `ca.crt` inside Mimir.

3. **Grafana → Mimir:**

   * Still uses mTLS directly for queries and dashboards.

4. **Result:**

   * Encrypted browser access ✅
   * Enforced mTLS internally ✅
   * Centralized HTTPS termination ✅

---

### **Caddy Configuration**

**docker-compose.yml**

```yaml
services:
  caddy:
    image: caddy:latest
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - ./certs:/etc/certs:ro
    depends_on:
      - grafana
      - mimir
    networks:
      - mononet

networks:
  mononet:
    external: true
```

**Caddyfile (final validated version)**

```caddy
grafana.localhost {
    reverse_proxy grafana:3000
    tls /etc/certs/central.crt /etc/certs/central.key
}

mimir.localhost {
    reverse_proxy https://mimir:9009 {
        transport http {
            tls
            tls_server_name mimir
            tls_client_auth /etc/certs/grafana.crt /etc/certs/grafana.key
            tls_trust_pool file /etc/certs/ca.crt
        }
    }
    tls /etc/certs/central.crt /etc/certs/central.key
}
```

✅ **Now both services are exposed securely** through Caddy, and internal mTLS is maintained.

---

## 🧩 6️⃣ Why Each Certificate Exists

| Certificate                   | Used By               | Purpose         | Authenticates         |
| ----------------------------- | --------------------- | --------------- | --------------------- |
| **ca.crt / ca.key**           | Certificate Authority | Root of trust   | Signs all other certs |
| **central.crt / central.key** | Mimir + Caddy         | Server identity | Mimir ↔ Clients       |
| **edge-a.crt / edge-a.key**   | Prometheus A          | Client identity | Prometheus A → Mimir  |
| **edge-b.crt / edge-b.key**   | Prometheus B          | Client identity | Prometheus B → Mimir  |
| **grafana.crt / grafana.key** | Grafana + Caddy       | Client identity | Grafana/Caddy → Mimir |

Each service has its own certificate so that:

* Identities are distinct and auditable.
* One compromise doesn’t affect others.
* Certificates can be rotated independently.

---

## ✅ 7️⃣ Security and Hardening Outcomes

| Goal                                       | Result                                             |
| ------------------------------------------ | -------------------------------------------------- |
| Encrypt all traffic in transit             | ✅ TLS across all connections                       |
| Verify identities of clients and servers   | ✅ mTLS with CA-signed certs                        |
| Isolate browser traffic from internal mTLS | ✅ Caddy terminates external HTTPS                  |
| Simplify certificate management            | ✅ Centralized through Caddy + CA                   |
| Support future auth controls               | ✅ Proxy layer allows adding basic auth/OAuth later |

---

## 🧾 8️⃣ Summary of Design Choices

| Decision                           | Reason                                                 |
| ---------------------------------- | ------------------------------------------------------ |
| **Use Caddy Proxy**                | Unified HTTPS entry point + automatic TLS/mTLS support |
| **Self-signed CA**                 | Local trust control without external dependency        |
| **Unique cert per service**        | Clear identity and revocation management               |
| **Mimir enforces mTLS**            | Ensures only trusted clients write/query metrics       |
| **Grafana and Edges use CA chain** | Consistent trust across all components                 |

---

## 🧠 Final Architecture Overview

**External Flow**

```
Browser  →  Caddy  →  Grafana
Browser  →  Caddy  →  Mimir
```

**Internal Flow (mTLS)**

```
Prometheus A/B  ⇄  Mimir
Grafana         ⇄  Mimir
```

All traffic → Encrypted (TLS)
All services → Authenticated (mTLS)
All users → Access HTTPS via Caddy
