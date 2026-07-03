# Workspace Rules

1. **Mandatory Brain.md Update:**
   - Every time a new feature is added, a bug is fixed, or any code is modified, you MUST automatically update the brain.md file without waiting for the user to ask.
   - The update should be appended under the current date (e.g., **Date: Month DD, YYYY**).
   - The entry must be highly detailed so any developer can understand exactly what changed. Include the version number if it was updated, mention which specific files were modified, explain the logic/UI changes clearly, and note if any specific events/components were removed or added.

2. **Clean Build Before Install:**
   - Whenever building and installing a new APK version on a device, you MUST run `flutter clean` and then `flutter pub get` before running the build command to clear the cache and ensure the new version is compiled rather than a cached old version.
