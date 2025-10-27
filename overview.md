# StatsDump Dataset Overview

## 📊 Summary
This dataset (`dbo.StatsDump`) represents a **comprehensive snapshot of system and application telemetry** gathered across multiple RDS servers, databases, web endpoints, and network interfaces in the Gaine monitoring environment.

It consolidates Windows system counters, service states, SQL Server metrics, and web response times into a unified format suitable for visualization in Grafana.

---

## 🧱 Table Structure
| Column | Type | Description |
|---------|------|-------------|
| **StatID** | INT | Unique identifier for each recorded metric. |
| **OwnerType** | INT | Type of entity owning this metric (e.g., system, app). |
| **ItemName** | NVARCHAR(100) | The object being measured (e.g., `C:`, `SQLActiveConnections`, `https://amg.gaine.com`). |
| **StatName** | NVARCHAR(100) | The metric or statistic being collected (e.g., `Free Bytes`, `ServiceUp`). |
| **OwningComputer** | NVARCHAR(100) | GUID or unique identifier for the host system where the stat originated. |
| **CompID** | INT | Internal numeric ID representing the host or component. |
| **StatType** | INT | Encoded type/category of the statistic (maps to system-level metric definitions). |
| **ItemAlias** | NVARCHAR(100) | Optional friendly name for display; often NULL. |
| **Unit** | INT | Encoded measurement unit (e.g., 1 = Bytes, 6 = %). |
| **UnitStr** | NVARCHAR(100) | Human-readable unit (e.g., `Bytes`, `%`). |
| **Name** | NVARCHAR(100) | Readable label or hostname (e.g., `RDS-JAVIERR`). |

---

## 🧠 What the Data Measures

The `StatsDump` table contains **29,401 total records** across **13 metric types (`StatName`)**, covering seven major system layers:

| **System Layer** | **Metrics** | **Purpose** |
|------------------|-------------|--------------|
| **🖥️ Host Storage** | `Free Bytes`, `Used Bytes`, `Percent Free` | Disk capacity and usage per drive (C:, D:, cluster shares). |
| **💾 Database** | `DB_PLUS_INDEX_SIZE`, `LOG_SIZE`, `DATABASE_PCT_USED`, `LOG_PCT_USED` | SQL Server database and log utilization for 6 production DBs. |
| **🌐 Network** | `BANDWIDTH_VALUE`, `PingTime` | Network bandwidth per adapter and latency to remote systems. |
| **⚙️ Performance Counters** | `CounterValue` | PerfMon counters (CPU, memory, paging, disk I/O). |
| **🧩 Services** | `ServiceUp` | Windows service uptime (1 = running, 0 = stopped). |
| **🌍 Web Applications** | `WebResponseTime` | Response time of Gaine web portals and UAT environments. |
| **🧱 Application/Framework** | `Recorded Data` | Custom counters like `.NET ActiveConnections`, SQL connection pools. |

---

## 📂 Example Observations

### 🖥️ Host Storage
- `ItemName`: `C:`, `c:\ClusterStorage\perf1\Shares\DB`
- `StatName`: `Free Bytes`, `Used Bytes`, `Percent Free`
- `UnitStr`: `Bytes`, `%`
- Measures **disk usage** on local and clustered drives.

### 💾 Database Metrics
- Databases monitored: `LICENSE_LANDING_PROD`, `SLN_MDX_PROD`, `USPS_REF`, etc.
- Tracks **database and log sizes**, both in raw bytes and percentage used.

### 🌐 Network Metrics
- `BANDWIDTH_VALUE`: Virtual NICs (Hyper-V Adapters)
- `PingTime`: RDS servers and SOFS file servers
- Measures **throughput and latency** across the network.

### ⚙️ Performance Counters
- `CounterValue` includes:
  - `Memory\% Committed Bytes In Use`
  - `Paging File(_Total)\% Usage`
  - `LogicalDisk(_Total)\% Disk Time`
- Captures **core system resource utilization.**

### 🧩 Services
- Tracks 447 Windows services, including:
  - `Dhcp`, `MSDTC`, `EraAgentSvc`, `CryptSvc`
- Used to ensure **critical system processes remain operational.**

### 🌍 Web Applications
- Monitors:
  - `https://amg.gaine.com`
  - `https://amg-uat.gaine.com`
  - `https://ftp.gaine.com`
- Measures **response times (ms)** for uptime and latency reporting.

### 🧱 Application Metrics
- Examples: `.NET NumberOfActiveConnections`, `SQLActiveConnections`
- Used for **connection pool** and **application health** insights.

---

## 📈 Data Composition

| **StatName** | **Count** | **Example ItemName** |
|---------------|-----------|----------------------|
| ServiceUp | 26,639 | `Dhcp`, `EventSystem`, `MSDTC` |
| CounterValue | 1,409 | `\\RDS-MIKEK\\Memory\\% Committed Bytes In Use` |
| BANDWIDTH_VALUE | 558 | `in_port.Microsoft Hyper-V Network Adapter _4` |
| Free Bytes | 189 | `C:` |
| Used Bytes | 189 | `C:` |
| Percent Free | 189 | `C:` |
| PingTime | 150 | `RDS-JAVIERR`, `SOFS4.GAINE.COM` |
| WebResponseTime | 28 | `https://amg.gaine.com` |
| DB_PLUS_INDEX_SIZE | 6 | `SLN_MDX_PROD` |
| LOG_SIZE | 6 | `SLN_MDX_PROD` |
| DATABASE_PCT_USED | 6 | `SLN_MDX_PROD` |
| LOG_PCT_USED | 6 | `SLN_MDX_PROD` |
| Recorded Data | 21 | `.NET NumberOfActiveConnections` |

---

## 🧩 Summary

In short, the `StatsDump` dataset provides:
- A **multi-layer snapshot** of the environment  
- Covering **storage**, **network**, **database**, **services**, and **applications**
- Ready to be visualized in **Grafana** via MSSQL datasource

You can use this structure to build:
- Storage health dashboards (Percent Free per drive)
- Network latency dashboards (PingTime)
- Database utilization panels (LOG_PCT_USED)
- Web uptime panels (WebResponseTime)
- Windows service availability grids (ServiceUp)

---

## 🗂️ Related Notes
- Total Rows: **29,401**
- Unique Metrics: **13**
- Primary Host Identifier: **Name** (`RDS-*`)
- Key Source ID: **CompID**
- Common Units: `Bytes`, `%`, `ms`
