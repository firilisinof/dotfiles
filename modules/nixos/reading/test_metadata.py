import importlib.util
import sys
import unittest
from pathlib import Path

module_path = sys.argv.pop(1)
sys.path.insert(0, str(Path(module_path).resolve().parents[2]))
from services.volume_enrichment.plan import build_plan

spec = importlib.util.spec_from_file_location("matching", module_path)
matching = importlib.util.module_from_spec(spec)
spec.loader.exec_module(matching)


class VolumeMatchingTest(unittest.TestCase):
    def volumes(self):
        return [
            {
                "id": 1,
                "minNumber": 1,
                "chapters": [{"id": 11, "minNumber": 1}, {"id": 12, "minNumber": 2}],
            },
            {
                "id": 2,
                "minNumber": 2,
                "chapters": [{"id": 13, "minNumber": 3}, {"id": 14, "minNumber": 4}],
            },
        ]

    def test_manga_chapters_share_their_volume_cover(self):
        units = matching.units_from_volumes(self.volumes(), library_type="Manga")
        index = {"1": {"cover_url": "volume-1"}, "2": {"cover_url": "volume-2"}}
        pairs, unmatched = matching.match_units(units, index)
        self.assertEqual(unmatched, [])
        self.assertEqual(
            [(unit["chapter_id"], data["cover_url"]) for unit, data in pairs],
            [(11, "volume-1"), (12, "volume-1"), (13, "volume-2"), (14, "volume-2")],
        )
        self.assertEqual(build_plan(units, index)["counts"]["duplicates"], 0)

    def test_repeated_volumes_remain_duplicates(self):
        volumes = self.volumes()
        volumes[1]["minNumber"] = 1
        units = matching.units_from_volumes(volumes, library_type="Manga")
        index = {"1": {"cover_url": "volume-1"}}
        self.assertEqual(build_plan(units, index)["counts"]["duplicates"], 4)

    def test_comics_keep_issue_numbers(self):
        for library_type in ("Comic", "ComicFlexible", ""):
            units = matching.units_from_volumes(
                self.volumes(), library_type=library_type
            )
            self.assertEqual(
                [matching.unit_number(unit) for unit in units], ["1", "2", "3", "4"]
            )

    def test_manga_without_volume_numbers_uses_chapters(self):
        volumes = self.volumes()
        for volume in volumes:
            volume["minNumber"] = matching.LOOSE_VOL
        units = matching.units_from_volumes(volumes, library_type="Manga")
        self.assertEqual(
            [matching.unit_number(unit) for unit in units], ["1", "2", "3", "4"]
        )

    def test_specials_do_not_receive_volume_covers(self):
        volumes = self.volumes()
        for volume in volumes:
            volume["minNumber"] = matching.SPECIAL_VOL
        units = matching.units_from_volumes(volumes, library_type="Manga")
        pairs, _ = matching.match_units(units, {"1": {"cover_url": "volume-1"}})
        self.assertEqual(pairs, [])


if __name__ == "__main__":
    unittest.main()
