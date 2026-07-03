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
- **Search Navigation Back-Stack (v10.1.45 Update):** Implemented an industry-standard navigation back-stack for the Search Page in `lib/screens/search_page.dart`.
  - *PopScope Integration:* Wrapped the `Scaffold` in a `PopScope` to intercept hardware back button presses.
  - *Search History Stack:* Added a `_searchStack` list to maintain the history of searches in the current session. When the back button is pressed, the app now pops the current search query and re-triggers the previous search query instead of instantly exiting the app or returning to the home screen.
- **UI Bug Fix (v10.1.46 Update):** Fixed a layout issue where the MiniPlayer would overlay and hide the bottom items of `ModalBottomSheet` widgets across the app (like Settings -> Audio Quality).
  - *Global Padding Fix:* Added `MiniPlayerBottomSpace()` to the bottom of the `Column` inside `showCustomBottomSheet` in `lib/utilities/flutter_bottom_sheet.dart` to automatically pad bottom sheets by the height of the mini player globally.
- **Search Suggestions Filter (v10.1.48 Update):** Improved search accuracy by filtering out irrelevant suggestions fetched from YouTube.
  - *Keyword Filtering:* Added logic in `getSearchSuggestions` (`lib/services/common_services.dart`) to block suggestions containing keywords like `lyrics`, `controversy`, `download`, `karaoke`, `ringtone`, `video`, `list`, `status`, `mp3`, and `audio`. This ensures users primarily see song and artist-related recommendations.
- **Like Button Animation & Color Fix (v10.1.50 Update):** Improved the visual feedback of the Like (Heart) button across the app (including Home Page).
  - *Global Component:* Extracted the animation logic into a new reusable `AnimatedLikeButton` widget (`lib/widgets/animated_like_button.dart`).
  - *Heartbeat Animation:* Implemented `SingleTickerProviderStateMixin` with an `AnimationController` and a bouncy `ScaleTransition`. When a user likes a song, the heart icon performs a heartbeat scale animation (`Curves.easeOutBack` into `Curves.elasticOut`).
  - *Color Update:* Changed the active like color from the default theme accent color to `Colors.redAccent` for a more natural, "heart-like" aesthetic.
  - *Home Page Integration:* Replaced the non-functional dummy `IconButton` in `home_page.dart`'s recommended songs list with the new `AnimatedLikeButton`.
- **Liked Songs Database Fix (v10.1.51 Update):** Fixed an issue where liking a song from the Home Page didn't save it to the "Liked Songs" section.
  - *Data Formatting:* Added logic in `home_page.dart` to inject the `ytid` field into `songData` before passing it to `AnimatedLikeButton`. This ensures `_resolveSongForLikedStatus` successfully parses and saves the song locally without dropping the event.
- **Like Button State Fix (v10.1.52 Update):** Resolved an issue where liking one recommended song on the Home Page would visually trigger all other recommended songs' like buttons simultaneously.
  - *ID Resolution Conflict:* The bug occurred because songs coming from the Home Page API only had an `id` field initially, but some API instances returned a missing `id`, causing multiple items to share the `null` identifier.
  - *Fallback Logic:* Implemented robust fallback logic in `AnimatedLikeButton` instantiation `(song['ytid'] ?? song['id'] ?? '').toString()` to ensure every song gets a unique valid ID, isolating their like states.
- **Home Page 3-Dot Menu Fix (v10.1.53 Update):** Activated the 3-dot options menu for recommended songs on the Home Page.
  - *OverflowMenuButton:* Replaced the non-functional dummy `IconButton` with a fully functional `OverflowMenuButton`.
  - *Actions Added:* Users can now click the 3 dots to "Play Next", "Add to Queue", and "Go to Artist" directly from the Home Page.
- **Mini Player Swipe-to-Dismiss (v10.1.54 Update):** Added the ability to swipe the mini player away to stop playback.
  - *Stop Action:* Configured `onDismissed` to trigger `audioHandler.stop()`, mirroring industry-standard music app behaviors like Spotify.
- **Mini Player Restore Bug Fix (v10.1.55 Update):** Resolved an issue where swiping the mini player away caused it to permanently disappear for subsequent songs until app restart.
  - *State Reset:* Added an internal `_isDismissed` state flag to track the swipe status.
  - *Automatic Re-initialization:* The flag is reset to `false` in `didUpdateWidget` whenever a new song is played or the play state toggles, forcing the `Dismissible` widget to successfully rebuild and reappear in the widget tree.
- **Mini Player Blank Space Padding Fix (v10.1.56 Update):** Removed the persistent black space (padding) left behind at the bottom of the screen when the mini player was swiped away.
  - *Visibility Sync:* Integrated `audioHandler.playbackStateStream` into `_miniPlayerVisibilityStream` via `Rx.combineLatest2`.
  - *Dynamic Padding:* The layout's bottom padding now dynamically collapses to `0` whenever `playbackState.processingState == AudioProcessingState.idle`, effectively removing the reserved empty space when playback is fully stopped.
- **Mini Player True Floating & Down Swipe (v10.1.57 Update):** Completely removed layout padding for the mini player so it floats directly over content, and added a swipe-down gesture.
  - *Float Fix:* Removed the dynamic padding calculation in `bottom_navigation_page.dart` completely. The background UI now extends all the way down, and the mini player acts as a true overlay.
  - *Down Swipe:* Updated `_handleVerticalDrag` in `mini_player.dart` to trigger `audioHandler.stop()` and `_isDismissed = true` on positive (downward) vertical swipes, in addition to the horizontal swipe.
- **Mini Player Down Swipe Animation (v10.1.60 Update):** Added visual feedback for the downward swipe gesture.
  - *Slide Animation:* Added a smooth 300ms downward sliding animation using `AnimatedSlide` that visually moves the mini player off-screen before stopping the audio, matching the native feel of the horizontal swipe.
- **Audio Fade-Out on Pause/Stop (v10.1.58 Update):** Added a premium, smooth fade-out audio effect whenever playback is stopped or paused from anywhere in the app.
  - *Fade Logic:* Implemented a private `_fadeOut()` async method in `audio_service.dart` that smoothly decrements the volume to zero over a 300ms duration (10 steps of 30ms each).
  - *Global Integration:* Integrated the fade-out seamlessly into both the `pause()` and `stop()` methods of `MusifyAudioHandler`. 
  - *Volume Reset:* Added a `_resetVolume()` utility that instantly restores the volume to `1.0` right after the player enters the paused/stopped state (and whenever playback restarts), ensuring subsequent plays start at full volume without delay.
- **Quick Picks Visibility Fix (v10.1.59 Update):** Fixed an issue where the "Quick picks" section (Quick Play) would completely disappear from the Home Page if the API failed to fetch related songs for a specific song in history.
  - *Robust Seed Fetching:* Updated `getQuickPicks()` in `common_services.dart` to collect a combined pool of up to 15 seed songs (from local history and trending).
  - *Fallback Loop:* Implemented a fallback loop that tries to fetch related videos for each seed song one by one. If one throws an error (e.g., due to an API change or unsupported video format), it gracefully catches the error and tries the next seed song instead of returning an empty list.
- **Shake to Skip Feature (v10.1.61 Update):** Implemented a complete motion-based gesture system that allows users to skip tracks by physically shaking their device. This is an industry-standard implementation with battery optimization and user-configurable settings.
  - **Dependency Installed:** Added `sensors_plus: ^7.1.0` in `pubspec.yaml` to gain access to the device's accelerometer sensors.
  - **Core Logic (`lib/services/shake_service.dart`):**
    - Created a singleton class `ShakeService` to centralize all motion detection logic.
    - Used `userAccelerometerEventStream(samplingPeriod: SensorInterval.gameInterval)` to listen to `UserAccelerometerEvent`. We used `userAccelerometer` instead of standard `accelerometer` to exclude the force of gravity and only capture the user's actual physical movements.
    - Added a magnitude calculation: `sqrt(x² + y² + z²)`. If the magnitude exceeds a specific threshold, a "shake" is registered.
    - **Events & Timing Logic:**
      - Added a 250ms debounce (`_lastShakeTime`) so the forward and backward motion of a single physical shake aren't counted as two separate shakes.
      - Implemented a **500ms Time-Window (`_singleShakeTimer`)**:
        - If `_shakeCount == 1` after 500ms, it triggers `audioHandler.skipToNext()`.
        - If a second shake occurs within that 500ms (`_shakeCount == 2`), the timer is canceled, and it immediately triggers `audioHandler.skipToPrevious()`.
      - **Cooldown (`_cooldownTimer`):** After any skip action is triggered, a 1.5-second cooldown locks the sensor. This prevents accidental rapid-fire skips.
      - **Haptic Feedback:** Used `HapticFeedback.mediumImpact()` to give the user a physical confirmation when a skip is triggered.
    - **Battery Optimization:** The stream listener explicitly checks `audioHandler.playbackState.value.processingState` and `playing`. If music is paused or idle, it returns immediately without doing math, saving battery life.
  - **Settings Integration (`lib/services/settings_manager.dart` & `lib/screens/settings_page.dart`):**
    - Added two new `ValueNotifier` states backed by Hive: `shakeToSkipEnabled` (default: false) and `shakeToSkipSensitivity` (default: 'medium').
    - Added a new UI block in `_buildPreferencesSection` of `settings_page.dart` (right after offline mode).
    - It contains a Master Toggle (Switch) and, if enabled, dynamically shows a "Shake Sensitivity" picker.
    - The sensitivity picker (`_showShakeSensitivityPicker`) is a Bottom Sheet with a `RadioListTile` offering three thresholds:
      - Low (Hard Shake): Threshold 25.0
      - Medium (Normal): Threshold 18.0
      - High (Light Shake): Threshold 12.0
  - **App Initialization (`lib/main.dart`):**
    - Imported `shake_service.dart` and called `ShakeService().init();` immediately after the `AudioService.init` block in `main()`, ensuring the listener is ready as soon as the app starts.
- **Shake to Skip Hardware False-Positive Fix (v10.1.62 Update):** Completely rewrote the shake logic to use an absolute "Orientation/Flat Lock" because Android's `userAccelerometer` produced fake acceleration spikes when the device was suddenly stopped (placed on a table/bed).
  - *Swapped Sensor:* Moved from `userAccelerometerEventStream` to `accelerometerEventStream` (which includes raw gravity).
  - *Custom Gravity HPF:* Implemented a manual high-pass filter (`alpha = 0.8`) to mathematically separate gravity from true linear acceleration without relying on the OS's delayed filter.
  - *Flat Lock Logic:* Added a critical check: `if (event.z.abs() > 7.5 || _gravityZ.abs() > 7.5) { return; }`. If the phone is lying flat on a table or bed (Z-axis gravity dominates), the entire shake system is temporarily disabled.
  - *Z-Axis Blindness & Shock Lock (Final Iteration):* Calculated magnitude using only X and Y (`sqrt(linearX*linearX + linearY*linearY)`) to blind the sensor to Z-axis drops (bed impacts). Added a 1000ms `_flatLockUntil` freeze when vertical shock `event.z > 12.0` occurs. 
  - **CURRENT STATUS (PAUSED):** Despite the above fixes, the logic performed flawlessly in `Debug` builds (due to slower event loop processing or Dart VM overhead) but continued to register false-positives upon bed impact in the `Release` build (which processes at 20ms `gameInterval` speeds, catching micro-bounces). 
  - **History of Attempted Fixes (For future reference):**
    1. *Cross-Axis Rejection:* Blocked triggers if Z/Y were higher than X. Failed because bed-bounce forces are chaotic across all axes.
    2. *Magnitude Low-Pass Filter:* Averaged the magnitude to smooth out spikes. Failed because multi-directional bounce energy collapsed into a single massive positive signal.
    3. *Axis-Specific LPF:* Filtered axes individually before calculating magnitude. Failed because OS-level sensor lag created synthetic acceleration on sudden stops.
    4. *Orientation/Gravity Lock:* Checked `event.z > 7.5` to disable if flat. Failed in Release mode because the impact bounce momentarily drops Z gravity below 7.5, opening the lock.
    5. *Z-Blindness & Shock Lock:* Ignored Z entirely for magnitude and froze sensor for 1 sec on impact. Still registered false-positives in Release mode (likely due to phone bouncing sideways (X/Y) on mattress springs or polling interval missing the exact frame of the lock). Work paused for now.
