# Nit Music - Update History & Brain

This file keeps track of all the changes and updates made to this personal music app.

## Updates Log

**Date: June 30, 2026**
- **Identity Removal:** Removed all references to original developer ("Valeri Gokadze" / "gokadzev"), deleted `LICENSE`, `CONTRIBUTING.md`, `.github`, etc.
- **Update Checks Disabled:** Removed all GitHub-based update checks and announcements so the app never tries to update from the original repository.
- **Package Name Changed:** Renamed the android package identifier to `com.musify.app`.
- **App Renamed:** Changed the app's display name from "Musify" to "Nit Music" in `AndroidManifest.xml`, Dart code, and all `.arb` translation files.
- **New AI Logo:** Generated a new premium AI logo (neon purple and blue) and replaced the app's launcher icons and internal assets (`assets/logo.png`).
- **Signing Fixed:** Configured the `release` build to use the default `debug` keystore to ensure the APK installs flawlessly on Android 11+ without throwing "Invalid Package" errors.
- **Search Speed Optimization:** Added 2-second timeouts to slow API requests (Artists, Albums, Playlists) in `Future.wait` during search. This drastically improved search speed by not blocking the fast song results.
- **Autoplay enabled:** Confirmed autoplay/default settings based on user request.
- **APK Generation:** Created and placed the final `NitMusic.apk` in the root directory for easy access.
- **UI Clean-up:** Completely removed the 'Licenses' and 'Translate' options from the Settings page to ensure no old UI elements or external links to the original developer exist.
- **UI Modernization:** Redesigned the mini player into a floating glassmorphism pill, rounded the search bar, added a SliverAppBar with gradient to the home screen, and updated the main headings to 'Nit Music'.
- **UI Clean-up:** Completely removed the 'Licenses' and 'Translate' options from the Settings page to ensure no old UI elements or external links to the original developer exist.
- **UI Modernization:** Redesigned the mini player into a floating glassmorphism pill, rounded the search bar, added a SliverAppBar with gradient to the home screen, and updated the main headings to 'Nit Music'.
- **Auto Updates setup:** Initialized Git and added GitHub action (.github/workflows/auto_release.yml) to automatically compile APK and push to Github Releases. Updated update_manager.dart to fetch OTA updates directly from GitHub API.

**Date: July 2, 2026**
- **True Listening History:** Fixed the audio player queue logic in  udio_service.dart so that starting a new song/playlist accurately saves the currently playing song to history. Tapping the "Previous" button now perfectly restores the previously playing song.
- **Generic Grid & See All:** Implemented a new GenericGridPage and updated outer_service.dart so the "See all" buttons on the Home Page (for Top Mixes, Recommended) now properly route to a full grid view.
- **Premium Bottom Navigation:** Rebuilt the bottom navigation to feature a sliding pill indicator with FastOutSlowIn easing. The icons, labels, and page transitions are now 100% perfectly synchronized, replicating the feel of YouTube Music.
- **Settings UI & Navigation Fixes:** Overhauled the Settings section by replacing persistent sheets with showModalBottomSheet. This fixed the broken back-button/orphaned overlay issues. Slightly reduced and refined typography across all settings for a cleaner, modern look.
- **Splash Screen Polish:** Refined the initial launch splash screen animation to use a premium, snappy `elasticOut` curve, and ensured it accurately reads the `has_seen_splash` flag so it only shows up on the first app launch.
- **Search UI Refinement:** Restored the text labels to the `CustomBottomNavigationBar` after a previous mistake, and verified that the large purple "Search" text issue reported on older APK versions was indeed already removed from the codebase.
- **Home Page Dynamic Header:** Replaced the hamburger menu icon on the Home page top bar with the official `Nit Music` app logo icon. Additionally, updated the "Music" text color to dynamically extract and match the vibrant color of the currently playing song's artwork, synchronizing with the Now Playing background.
- **Update Logic Fixed:** Fixed a bug where the "Update Available" dialog kept appearing because of mismatched hardcoded versions. Also added a `checkAppUpdates` block to ensure the update dialog only appears once per session and only when genuinely required.
- **Trending Section Aspect Ratio:** Adjusted the "Trending Now" images from a 1:1 square to a 16:9 rectangle (220x124) so that YouTube thumbnails are no longer aggressively cropped from the top and bottom.
- **Bottom Navigation Sync & Layout:** Corrected the `CustomBottomNavigationBar` pill indicator synchronization issue where it failed to highlight Library and Settings due to an `AnimationController` upper bound constraint. Also fixed a `Stack` positioning bug where the indicator pill incorrectly overlapped text.
- **Now Playing Collapse Animation:** Fixed the jittering "Collapse Player" (down arrow) button during the transition between the full-screen player and the mini player. Achieved perfect synchronization by wrapping the button in a `Hero` widget with a custom `flightShuttleBuilder`, smoothly interpolating opacity and position along with the player background.
- **Optimized Live Search UI & Logic:** Completely overhauled the search experience to mimic YouTube Music's live search.
  - *UI Changes:* Converted the bulky `CustomBar` search suggestions into a compact `ListTile` with a faded matching query, search icon, and top-left arrow. Displayed both the suggestions and real-time Artist/Song results simultaneously in a `Column` without requiring the user to press Enter.
  - *API Optimizations (Dual-Debounce):* Implemented a `300ms` debounce for light text suggestions, and a heavier `700ms` dual-debounce explicitly for fetching live songs. Also enforced a minimum 2-character limit and request cancellation to protect the backend from spam/flooding during rapid typing.

**Date: July 3, 2026**
- **YouTube Song Title Cleanup (v10.1.37):** Implemented a robust title formatting logic (`formatSongTitle`) in `lib/utilities/formatter.dart` to clean messy YouTube titles before they reach the UI. 
  - *Regex Filters Added:* Stripped out all hashtags (`#newsong`, `#trending`), emojis (`🔥🎵`), unnecessary bracket contents like `(From "Movie")`, and junk video tags (`Full Video Song`, `HD`, `4K`, `Audio Jukebox`). 
  - *Pipe Stripping:* Added logic to aggressively remove anything after the pipe character (`|`), which usually contains channel names or promotional text.
  - *Regression Testing:* Wrote `test/formatter_test.dart` with 22 distinct unit tests covering edge cases to guarantee the formatting logic won't break in the future.
- **Search Result Filters (v10.1.38):** Added UI category filters directly below the search bar in `lib/screens/search_page.dart` to drastically improve user search experience. 
  - *UI Implementation:* Added horizontally scrolling `ActionChip` widgets with the options: **All, 🎵 Songs, 👤 Artists, 💿 Albums, ▶️ Playlists**.
  - *Logic Update:* Modified the `_buildSearchResults` method. Now, when a specific filter (e.g., 'Songs') is tapped, the `_activeFilter` state updates, and all other unselected sections (Artists, Albums, Playlists) are dynamically hidden from the UI.
- **Infinite Scrolling for Search Results (v10.1.39):** Implemented seamless auto-pagination for song search results in `lib/screens/search_page.dart`.
  - *Scroll Detection:* Attached a `ScrollController` to the `SingleChildScrollView` to detect when the user scrolls within 200 pixels of the bottom edge.
  - *Pagination Logic:* Switched the initial search from `fetchSongsList` to `fetchSongsListWithPagination` to capture the YouTube `nextPage` token. When the scroll threshold is reached, `_loadMoreSongs` invokes `fetchNextSongsList`, appending the next 20-30 songs dynamically.
  - *UI Enhancements:* Bypassed the hardcoded `maxSongsInList = 15` limit when the 'Songs' filter is active, allowing infinite rendering. Added a `CircularProgressIndicator` at the bottom of the list to signify background loading.
- **Double-Tap Search Tab to Reset (v10.1.40):** Added functionality to clear the active search and return to the recommended/default state when the Search icon on the bottom navigation is tapped while already on the search page.
  - *Event Broadcasting:* Created a global `ValueNotifier<int> searchTabReselectNotifier` in `lib/screens/bottom_navigation_page.dart`. This triggers whenever `isReselect` is true and the active route is `/search`.
  - *State Reset:* Added a listener `_onReselectTab` in `lib/screens/search_page.dart`'s `initState` that clears `_searchBar`, clears all search result arrays (`_songsSearchResult`, `_artistsSearchResult`, etc.), resets the `_activeFilter` to `'All'`, and unfocuses the keyboard.
- **Pre-loading Skeleton Loaders (v10.1.41):** Added smooth shimmer skeleton animations to the Home and Search pages while waiting for network responses.
  - *Skeleton Widget:* Created `lib/widgets/skeleton_loader.dart` leveraging the `shimmer` package to provide `MixCardSkeleton` and `SongBarSkeleton`.
  - *Home Page Integration:* Replaced empty/spinner states in `AsyncLoader` for `_suggestedPlaylistsFuture`, `_trendingSongsFuture`, and `_recommendedSongsFuture` with the custom skeleton widgets.
  - *Search Page Integration:* Updated `_buildRecommendations` to show 4 dummy `SongBarSkeleton` elements while `_isLoadingRecommendations` is true, replacing the standard `CircularProgressIndicator`.
- **Dynamic Theme Color Contrast Fix (v10.1.42):** Resolved an issue where light album artwork caused text and icons in the Now Playing screen and Queue modal to become invisible (black text on dark backgrounds).
  - *Gradient Adjustment:* Lowered the alpha values of `_vibrantColor` and `_dominantColor` in the background `LinearGradient` of `lib/screens/now_playing_page.dart` to maintain a darker, legible background.
  - *Text Theming Logic:* Removed the `onSurface` and `onSurfaceVariant` text overrides in `dynamicColorScheme`. Text and standard UI icons will now adhere to the default theme (white/light gray), guaranteeing readability over the dark-faded gradient, while preserving dynamic colors for the primary progress slider.
- **Home Page Quick Picks & Speed Dial (v10.1.43):** Added personalized content discovery sections to `lib/screens/home_page.dart` mirroring YouTube Music's layout.
  - *Speed Dial:* Implemented a horizontally scrolling list displaying the top 10 most frequently played songs/playlists from local Hive storage (`userRecentlyPlayed`). Operates entirely offline without API calls via a new `getSpeedDial` function in `lib/services/common_services.dart`.
  - *Quick Picks:* Added a vertically scrolling section displaying up to 4 personalized recommendations, generated by picking a random seed from recent history and fetching related videos from the YouTube API (`getQuickPicks` in `lib/services/common_services.dart`). 
  - *Play All:* Included a "Play all" button for Quick Picks that queues and plays all 20 fetched related songs seamlessly.
- **YouTube Title Formatter Fixes (v10.1.44):** Improved the robust title extraction logic in `lib/utilities/formatter.dart` to handle edge cases common in regional music.
  - *Smart Pipe Stripping:* Changed the pipe (`|`) logic to strip emojis and hashtags *before* splitting by pipe, ensuring that valid song names aren't discarded when preceded by a hashtag (e.g., `#Video | Song Name`).
  - *Artist Prefix Truncation:* Modified `formatSongTitle` to accept an `author` parameter. If a YouTube title starts with the channel/artist name followed by a colon or dash (e.g., `Singer Name : Song Name`), the prefix is automatically stripped so the actual song name is clearly visible in the UI without being truncated by an ellipsis.
  - *Unit Tests Added:* Wrote additional regression tests in `test/formatter_test.dart` to strictly verify these new title configurations.
