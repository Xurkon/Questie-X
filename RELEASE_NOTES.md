## v1.4.4 — AceGUI Pool & Event Handling Fixes

### AceGUI Fixes
- Fixed `Compat/embeds.xml` to load Wrath-compatible Ace library versions from `Libs/` (AceGUI-3.0 v34, AceConfigDialog-3.0 v66) instead of newer versions that caused widget pool corruption
- Added nil checks throughout AceGUI-3.0 to prevent crashes when pooled widgets have corrupted/nil properties
- Applied fixes to both `Libs/AceGUI-3.0/` and `Compat/Libs/AceGUI-3.0/`

### Event Handling Fixes
- Fixed "bad argument #1 to 'find'" error in `ChatMsgSystem`
- Fixed "number expected, got nil" error in `SetPlayerLevel`

### QuestieLearner Fixes
- Added robust `SanitizeData` function with depth limiting to filter functions/userdata/thread from learned data
- Added pcall wrapper around AceSerializer to catch and log errors instead of crashing
- Added early return checks for nil/empty data

### Journey Fixes
- Fixed "attempt to index local 'container'" error in tab handling

### Localization Fixes
- Fixed "bad argument #2 to 'format'" error when translation is not a string or format arguments are missing

### Files Changed
- 26 files changed, 569 insertions(+), 83 deletions(-)