import os
import sys
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

DISABLED = (
    "DisableScriptInjectionMiddleware",
    "EnableCustomSplashScreen",
    "EnableLoginImage",
    "DevMode",
    "MaintenanceModeEnabled",
    "MaintenanceScheduleEnabled",
    "ElsewhereEnabled",
    "ElsewhereSeasonProviders",
    "AutoPauseEnabled",
    "AutoResumeEnabled",
    "AutoPipEnabled",
    "AutoSkipIntro",
    "AutoSkipOutro",
    "LongPress2xEnabled",
    "RandomButtonEnabled",
    "ShowWatchProgress",
    "ShowFileSizes",
    "RemoveContinueWatchingEnabled",
    "ShowAudioLanguages",
    "ShowReviews",
    "ShowUserReviews",
    "ShowAnilistReviews",
    "ReviewTranslationEnabled",
    "MirrorReviewRatingsToJellyfin",
    "ShowAwards",
    "DoesTheDogDieEnabled",
    "MdblistRatingsEnabled",
    "MdblistRatingsFetchEnabled",
    "MdblistRatingsAutoSyncEnabled",
    "ShowReleaseDates",
    "ShowUserRatingOnPosters",
    "PauseScreenEnabled",
    "ShowPlaybackRatingBadge",
    "QualityTagsEnabled",
    "GenreTagsEnabled",
    "LanguageTagsEnabled",
    "RatingTagsEnabled",
    "AgeRatingTagsEnabled",
    "PeopleTagsEnabled",
    "NativePosterTagsEnabled",
    "TagCacheServerMode",
    "EnableTagsLocalStorageFallback",
    "ShowRatingInPlayer",
    "JellyseerrShowReportButton",
    "JellyseerrShowIssueIndicator",
    "JellyseerrEnable4KRequests",
    "JellyseerrEnable4KTvRequests",
    "JellyseerrShowAdvanced",
    "JellyseerrShowSimilar",
    "JellyseerrShowRecommended",
    "JellyseerrShowNetworkDiscovery",
    "JellyseerrShowGenreDiscovery",
    "JellyseerrShowTagDiscovery",
    "JellyseerrShowPersonDiscovery",
    "JellyseerrShowCollectionDiscovery",
    "JellyseerrSearchExcludeLibraryItems",
    "JellyseerrAutoImportUsers",
    "ShowElsewhereOnJellyseerr",
    "ShowCollectionsInSearch",
    "TriggerSeerrScanOnItemAdded",
    "ArrLinksEnabled",
    "ArrTagsSyncEnabled",
    "ArrTagsShowAsLinks",
    "AudioLanguageTagSyncEnabled",
    "AudioLanguageTagShowAsLinks",
    "LetterboxdEnabled",
    "MetadataIconsEnabled",
    "AutoSeasonRequestEnabled",
    "AutoMovieRequestEnabled",
    "AddRequestedMediaToWatchlist",
    "SyncJellyseerrWatchlist",
    "SyncJellyfinWatchlistToSeerr",
    "BookmarksEnabled",
    "ColoredRatingsEnabled",
    "ThemeSelectorEnabled",
    "ColoredActivityIconsEnabled",
    "PluginIconsEnabled",
    "ActiveStreamsEnabled",
    "ActivityFeedEnabled",
    "DownloadsPageEnabled",
    "CalendarPageEnabled",
    "RecommendationsPageEnabled",
    "HiddenContentEnabled",
    "CatchUpEnabled",
    "CatchUpLogEnabled",
    "SpoilerBlurEnabled",
    "SpoilerAutoEnableOnFirstPlay",
    "SpoilerAutoEnableOnSeerrRequest",
    "SpoilerAutoEnableOnLibraryAdd",
    "AnalyticsEnabled",
    "AnalyticsShareFeatureFlags",
    "AnalyticsShareUsageCounts",
    "AnalyticsShareDataSizes",
)


def main():
    path = Path(sys.argv[1])
    key = (
        (Path(os.environ["CREDENTIALS_DIRECTORY"]) / "seerr-api-key")
        .read_text()
        .strip()
    )
    if not key:
        raise ValueError("Seerr API key is empty")

    root = (
        ET.parse(path).getroot() if path.exists() else ET.Element("PluginConfiguration")
    )
    settings = dict.fromkeys(DISABLED, "false")
    settings.update(
        DisableBrandingMiddleware="true",
        DisableAllShortcuts="true",
        DisableCustomSubtitleStyles="true",
        JellyseerrEnabled="true",
        JellyseerrShowSearchResults="true",
        JellyseerrShowRequestMoreOnSeries="true",
        JellyseerrShowQuotaInfo="true",
        JellyseerrShowDetailPageLink="true",
        JellyseerrUseMoreInfoModal="true",
        JellyseerrUrls="http://127.0.0.1:5055",
        JellyseerrUrlMappings="https://watch.firilisinof.com|https://requests.firilisinof.com",
        JellyseerrApiKey=key,
    )
    for name, value in settings.items():
        element = root.find(name)
        if element is None:
            element = ET.SubElement(root, name)
        element.text = value

    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as handle:
            temporary = Path(handle.name)
            ET.ElementTree(root).write(handle, encoding="utf-8", xml_declaration=True)
        temporary.replace(path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
