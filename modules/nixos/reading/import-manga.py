import os
from pathlib import Path
import sys
import xml.etree.ElementTree as ET
import zipfile


source = Path(sys.argv[1])
destination = Path(sys.argv[2])
os.umask(0o007)
for archive in source.rglob('*.cbz'):
    if archive.is_symlink():
        continue
    target = destination / archive.relative_to(source)
    if target.exists() and os.path.samefile(archive, target):
        continue
    before = archive.stat()
    try:
        with zipfile.ZipFile(archive) as book:
            ET.fromstring(book.read('ComicInfo.xml'))
            if book.testzip() is not None:
                raise ValueError('Archive checksum failed')
    except (zipfile.BadZipFile, KeyError, ET.ParseError, ValueError) as error:
        print(f'Skipping incomplete archive {archive}: {error}')
        continue
    after = archive.stat()
    if (before.st_size, before.st_mtime_ns) != (after.st_size, after.st_mtime_ns):
        continue
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = target.with_suffix('.cbz.partial')
    temporary.unlink(missing_ok=True)
    os.link(archive, temporary)
    temporary.replace(target)
    print(f'Imported {target.relative_to(destination)}')
