import os
from pathlib import Path
import sys
import tempfile
import xml.etree.ElementTree as ET


def main():
    destination = Path(sys.argv[1])
    destination.mkdir(mode=0o700, parents=True, exist_ok=True)

    for name in ("sonarr", "radarr"):
        source = Path(f"/var/lib/{name}/config.xml")
        key = ET.parse(source).getroot().findtext("ApiKey")
        if not key:
            raise ValueError(f"{source} does not contain an API key")

        temporary = None
        try:
            with tempfile.NamedTemporaryFile(
                mode="w", dir=destination, delete=False
            ) as handle:
                temporary = Path(handle.name)
                handle.write(key)
                handle.write("\n")
            os.chmod(temporary, 0o600)
            temporary.replace(destination / name)
        finally:
            if temporary is not None:
                temporary.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
