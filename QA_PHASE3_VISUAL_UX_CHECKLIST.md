# QA Phase 3 - Visual and UX Regression Checklist

## Build Gate
- Run `checkBuild` task and ensure output includes `Build ok`.

## EditorCard Visual Parity
- Open New Prompt and verify title, description, icon, and primary editor spacing are unchanged.
- Verify category pill picker remains under the main editor with same spacing and transition.
- Verify primary editor border behavior:
  - idle border width matches previous baseline
  - focused/typing border thickens
  - hover shadow appears only when expected

## SecondaryEditorCard Visual Parity
- Open sections using secondary editors (negative/alternative where applicable).
- Verify header line keeps icon + uppercase title + optional actions aligned.
- Verify secondary editor border radius and border widths match baseline look.
- Verify placeholder still appears only when editor text is empty.

## AI Toolbar and Actions
- Validate AI buttons are enabled only when provider configuration is valid.
- Trigger each available AI action and confirm:
  - thinking message appears
  - success clears message and updates selected text / prompt
  - error shows toast with auto-clear
- Validate `instruct` action opens command alert and executes using entered instruction.

## Keyboard and Overlay Behavior
- Validate keyboard shortcuts still route correctly:
  - overlay navigation first
  - gallery/media shortcuts
  - save/copy/paste
  - escape/focus shortcuts
- Confirm variables/snippets overlays still support arrow navigation + enter selection.

## Smoke Cases
- Magic image drop still generates title/content for main editor.
- Zen mode opening from toolbar still works for main and secondary cards.
- No visual jump/flicker when hovering editor cards repeatedly.
- While typing continuously, move mouse in/out of editor cards and confirm no border animation jitter.

## Accessibility Motion
- Enable macOS Reduce Motion and verify editor card interactions still work (focus, hover, typing feedback).
- Confirm no continuous decorative animation is required to complete core flows.
- Disable Reduce Motion and verify baseline animations match expected visual behavior.

## Pass Criteria
- No new compile errors.
- No visual regressions in main add prompt flow.
- No interaction regressions in AI and keyboard handling.

## Supporting Artifacts
- Snapshot guide: `QA_EDITOR_CRITICAL_SNAPSHOTS.md`
- Profiling notes + trace path: `QA_PHASE3_PROFILING_NOTES.md`
