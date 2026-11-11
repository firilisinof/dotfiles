import json
import secrets
import sys
import time
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


def setup(hub_url, email, hostname, monitors_path, key_path):
    def request(path, data=None, method=None):
        body = None if data is None else json.dumps(data).encode()
        req = Request(
            f"{hub_url}{path}",
            data=body,
            headers={"Content-Type": "application/json"},
            method=method,
        )
        with urlopen(req, timeout=10) as response:
            body = response.read()
        return json.loads(body) if body else None

    def records(collection):
        items = []
        page = 1
        while True:
            result = request(
                f"/api/collections/{collection}/records?perPage=100&page={page}"
            )
            items.extend(result["items"])
            if page >= result["totalPages"]:
                return items
            page += 1

    for attempt in range(30):
        try:
            first_run = request("/api/beszel/first-run")["firstRun"]
            break
        except HTTPError:
            raise
        except (URLError, TimeoutError):
            if attempt == 29:
                raise
            time.sleep(1)

    if first_run:
        request(
            "/api/beszel/create-user",
            {"email": email, "password": secrets.token_urlsafe(48)},
        )

    user = request("/api/collections/users/auth-refresh", {}, "POST")["record"]
    system_data = {
        "name": hostname,
        "host": "127.0.0.1",
        "port": "45876",
        "users": [user["id"]],
    }
    systems = [
        system
        for system in records("systems")
        if system["host"] == system_data["host"]
        and str(system["port"]) == system_data["port"]
    ]
    if len(systems) > 1:
        raise ValueError("multiple Beszel systems use 127.0.0.1:45876")
    if systems:
        system = request(
            f"/api/collections/systems/records/{systems[0]['id']}",
            system_data,
            "PATCH",
        )
    else:
        system = request(
            "/api/collections/systems/records", {**system_data, "status": "pending"}
        )

    existing = [
        record
        for record in records("network_monitors")
        if record["system"] == system["id"]
    ]
    declared = set()
    for monitor in json.loads(Path(monitors_path).read_text()):
        data = {
            "system": system["id"],
            "protocol": "http",
            "port": 0,
            "interval": 60,
            "enabled": True,
            **monitor,
        }
        matches = [
            record
            for record in existing
            if all(
                record[key] == data[key]
                for key in ("system", "protocol", "target", "port")
            )
        ]
        if matches:
            declared.add(matches[0]["id"])
            request(
                f"/api/collections/network_monitors/records/{matches[0]['id']}",
                data,
                "PATCH",
            )
        else:
            request("/api/collections/network_monitors/records", data)
    for record in existing:
        if record["id"] not in declared:
            request(
                f"/api/collections/network_monitors/records/{record['id']}",
                method="DELETE",
            )

    key = request("/api/beszel/info")["key"]
    if not key.startswith("ssh-ed25519 "):
        raise ValueError("Beszel hub returned an invalid SSH public key")
    Path(key_path).write_text(f"{key}\n")
    print(f"configured {hostname} and its service monitors")


if __name__ == "__main__":
    setup(*sys.argv[1:])
