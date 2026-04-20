# QA Editor Critical Snapshots

## Goal

Capture consistent visual snapshots of critical editor sections after refactors.

## Snapshot Set

- New Prompt full screen (default state)
- EditorCard header (icon + title + description + magic controls)
- EditorCard main text area (idle, hover, typing)
- PromptImageShowcaseView (0 images, 1 image, full slots)
- SecondaryEditorCard (empty placeholder and filled content)
- AI error state branch message
- AI thinking state branch message
- Reduce Motion ON state for editor cards

## Capture Rules

- Use same app window size for all captures.
- Use same font size and same language per run.
- Disable random/dynamic content where possible.
- Capture both Light and Dark system appearances if applicable.

## Baseline Naming

- `snapshot_editor_default.png`
- `snapshot_editor_typing.png`
- `snapshot_showcase_empty.png`
- `snapshot_showcase_full.png`
- `snapshot_secondary_empty.png`
- `snapshot_secondary_filled.png`
- `snapshot_ai_thinking.png`
- `snapshot_ai_error.png`
- `snapshot_reduce_motion.png`

## Pass Criteria

- No spacing drifts in title/description/icon row.
- No border radius/width regressions in editor cards.
- No slot geometry regression in showcase strip during resize.
- Branch message placement and truncation remain stable.
