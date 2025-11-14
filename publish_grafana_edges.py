import json, os, re, requests

# ── Env vars ─────────────────────────────────────────────────────────────

GRAFANA_URL   = os.environ["GRAFANA_URL"]
GRAFANA_TOKEN = os.environ["GRAFANA_TOKEN"]

EDGES = [
    e.strip()
    for e in os.environ.get("EDGES", "edge-a,edge-b").split(",")
    if e.strip()
]

FOLDER_TITLE  = os.environ.get("FOLDER_TITLE", "Edges")
FOLDER_UID    = os.environ.get("FOLDER_UID", "edges-folder")
TEMPLATE_PATH = os.environ.get("TEMPLATE_PATH", "central/grafana/dashboards/edge-template.json")

# prefix used when naming datasources, e.g. "Mimir - edge-a"
DATASOURCE_PREFIX = os.environ.get("DATASOURCE_PREFIX", "Mimir - ")

# central mimir URL from inside Grafana container
MIMIR_URL = os.environ.get("MIMIR_URL", "https://mimir:9009/prometheus")

# optional: paths to certs if you want to push mTLS config via API
CA_CERT_PATH     = os.environ.get("CA_CERT_PATH")      # e.g. "certs/ca.crt"
CLIENT_CERT_PATH = os.environ.get("CLIENT_CERT_PATH")  # e.g. "certs/grafana.crt"
CLIENT_KEY_PATH  = os.environ.get("CLIENT_KEY_PATH")   # e.g. "certs/grafana.key"

H = {
    "Authorization": f"Bearer {GRAFANA_TOKEN}",
    "Content-Type": "application/json",
}

# ── Small wrappers around the Grafana API ────────────────────────────────

def gget(path):
    r = requests.get(GRAFANA_URL + path, headers=H)
    r.raise_for_status()
    return r.json()

def gpost(path, body):
    r = requests.post(GRAFANA_URL + path, headers=H, data=json.dumps(body))
    r.raise_for_status()
    return r.json()

def gput(path, body):
    r = requests.put(GRAFANA_URL + path, headers=H, data=json.dumps(body))
    r.raise_for_status()
    return r.json()

# ── Folder helpers ───────────────────────────────────────────────────────

def ensure_folder():
    import requests as rq
    try:
        gget(f"/api/folders/uid/{FOLDER_UID}")
        print(f"Folder '{FOLDER_TITLE}' already exists")
    except rq.HTTPError as e:
        if e.response is not None and e.response.status_code == 404:
            body = {"uid": FOLDER_UID, "title": FOLDER_TITLE}
            resp = gpost("/api/folders", body)
            print(f"Created folder '{FOLDER_TITLE}' -> {resp.get('url')}")
        else:
            raise

# ── Datasource helpers ───────────────────────────────────────────────────

def read_file_or_none(path):
    if not path:
        return None
    with open(path, "r", encoding="utf-8") as f:
        return f.read()

CA_CERT_PEM     = read_file_or_none(CA_CERT_PATH)
CLIENT_CERT_PEM = read_file_or_none(CLIENT_CERT_PATH)
CLIENT_KEY_PEM  = read_file_or_none(CLIENT_KEY_PATH)

def datasource_name(edge: str) -> str:
    return f"{DATASOURCE_PREFIX}{edge}"

def ensure_datasource_for_edge(edge: str) -> str:
    """
    Ensure a Prometheus/Mimir datasource exists for this edge/tenant.
    Returns the datasource UID.
    """
    name = datasource_name(edge)
    import requests as rq

    # try to look it up by name first
    try:
        data = gget(f"/api/datasources/name/{name}")
        print(f"Datasource '{name}' already exists (id={data['id']})")
        return data["uid"]
    except rq.HTTPError as e:
        if e.response is None or e.response.status_code != 404:
            raise
        print(f"Datasource '{name}' not found, creating…")

    # build datasource definition
    body = {
        "name": name,
        "type": "prometheus",
        "access": "proxy",
        "url": MIMIR_URL,
        "isDefault": False,
        "editable": True,
        "jsonData": {
            # multi-tenant header
            "httpHeaderName1": "X-Scope-OrgID",
            # mTLS flags if you use client certs
            "tlsAuth": bool(CLIENT_CERT_PEM and CLIENT_KEY_PEM),
            "tlsAuthWithCACert": bool(CA_CERT_PEM),
        },
        "secureJsonData": {
            # tenant ID = edge name
            "httpHeaderValue1": edge,
        },
    }

    # optionally embed certs
    if CA_CERT_PEM:
        body["secureJsonData"]["tlsCACert"] = CA_CERT_PEM
    if CLIENT_CERT_PEM:
        body["secureJsonData"]["tlsClientCert"] = CLIENT_CERT_PEM
    if CLIENT_KEY_PEM:
        body["secureJsonData"]["tlsClientKey"] = CLIENT_KEY_PEM

    created = gpost("/api/datasources", body)
    print(f"Created datasource '{name}' (id={created['id']}, uid={created['uid']})")
    return created["uid"]

# ── Dashboard helpers ────────────────────────────────────────────────────

def uid_safe(edge: str) -> str:
    uid = re.sub(r"[^a-z0-9_-]", "-", edge.lower())
    return uid[:36]

def ensure_dashboard_for_edge(edge: str, ds_uid: str, template: str):
    uid_suffix = uid_safe(edge)
    rendered = (
        template
        .replace("${EDGE_NAME}", edge)
        .replace("${DATASOURCE_UID}", ds_uid)
        .replace("${UID_SUFFIX}", uid_suffix)
    )

    payload = {
        "dashboard": json.loads(rendered),
        "folderUid": FOLDER_UID,
        "message": f"CI update for {edge}",
        "overwrite": True,
    }

    resp = gpost("/api/dashboards/db", payload)
    print(f"Upserted dashboard for {edge} -> {resp.get('url')}")

# ── Main ─────────────────────────────────────────────────────────────────

def main():
    ensure_folder()

    with open(TEMPLATE_PATH, "r", encoding="utf-8") as f:
        template = f.read()

    for edge in EDGES:
        ds_uid = ensure_datasource_for_edge(edge)
        ensure_dashboard_for_edge(edge, ds_uid, template)

if __name__ == "__main__":
    main()
