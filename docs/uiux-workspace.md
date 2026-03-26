# Adaptive UI workspace contract

This document records the approved UI/UX contract for the AudioConverter SwiftUI shell refresh described in `.omx/plans/prd-audioconverter-uiux-improvement.md` and `.omx/plans/test-spec-audioconverter-uiux-improvement.md`.

## Review summary

The existing shell already has the right behavioral seams (`AppState`, reusable SwiftUI components, stable UI-test hooks), but the presentation layer needs stricter hierarchy discipline:
- `MainView` must stay a single root `ScrollView`, but stop presenting the full workflow as one flat stack.
- Control/query identifiers must stay singular across adaptive layouts so existing XCUI selectors remain unambiguous.
- Typography and surfaces must converge on one restrained macOS-native token set instead of mixing multiple unrelated fonts and card treatments.
- Empty, blocked, in-flight, cancelled, and completed states must read clearly without changing conversion or merge semantics.

## Non-negotiable constraints

1. Preserve `AppState` mutation and gating behavior.
2. Keep one root `ScrollView` for the main workspace.
3. Do not render duplicate adaptive copies of any interactive control or accessibility identifier.
4. Keep one accent color and lightweight macOS-native styling; avoid web-style hero cards, gradients, or decorative chrome.
5. Preserve the existing selector contract unless tests are updated in the same change set.

## Layout contract

### 960px and wider
- Present one scrollable workspace with two visual zones:
  - **Primary lane:** header, banner, file staging
  - **Secondary lane:** mode, format, destination, action, supporting status
- Keep the batch-status surface visible in the default window without pushing the primary CTA cluster below the fold.

### 720px minimum width
- Collapse to one column in this order:
  1. header + banner
  2. file staging
  3. mode / format / destination / actions / supporting status
  4. batch status
- No horizontal scrolling should be required for `select-files`, merge reordering controls, primary CTA buttons, or batch summaries.

## Component ownership

- `MainView`: adaptive grouping only; preserve one interactive instance per control/ID.
- `FileSelectionView`: blocked, empty, staged, and reorder-ready states.
- `FormatInputView`: enabled/disabled format entry and quick-pick chips.
- `StatusBannerView`: startup-checking, blocked, ready, and in-flight emphasis.
- `BatchStatusListView`: compact empty state, readable live/completed rows, and stable summary identifiers.
- Invalid-format messaging remains owned by `MainView` unless tests and selector expectations move with it.

## Selector contract

These identifiers are part of the UI verification surface and should remain stable and singular:
- `mode-batch`
- `mode-merge`
- `select-files`
- `staged-file-name-*`
- `move-staged-file-up-*`
- `move-staged-file-down-*`
- `remove-staged-file-*`
- `select-merge-destination`
- `merge-destination-name`
- `start-conversion`
- `cancel-conversion`
- `start-merge`
- `cancel-merge`
- `retry-startup-check`
- `status-message`
- `batch-file-*`
- `batch-state-*`
- `batch-detail-*`
- `batch-progress-*`
- `batch-progress-label-*`
- `batch-summary-*`

## Verification checklist

### Automated
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme AudioConverter -destination 'platform=macOS' \
  -only-testing:AudioConverterUITests test

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme AudioConverter -destination 'platform=macOS' test
```

### Manual width/state checks
- **720px:** confirm the single-column order, no hidden CTA controls, and reachable batch-status summary.
- **960px:** confirm staging and control lanes are simultaneously legible before scrolling.
- **Blocked startup:** `retry-startup-check` remains distinct from the primary CTA cluster.
- **Merge mode:** destination selection remains separate from the start/cancel controls.
- **Live/completed work:** batch empty state stays compact before work begins, then expands cleanly once snapshots exist.

## Review handoff notes

If a future modifier needs to change the adaptive layout, verify the scroll-container assumption and selector uniqueness before touching `MainView` or duplicating controls into separate wide/narrow trees.
