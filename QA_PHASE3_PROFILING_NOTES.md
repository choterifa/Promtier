# QA Phase 3 Profiling Notes

## Environment
- Tool: `xcrun xctrace`
- Template: `Time Profiler`
- Duration: 8s
- Build: Debug, macOS arm64

## Recorded Trace
- Path: `profiling/Promtier_TimeProfiler.trace`
- Capture command:
  `xcrun xctrace record --template 'Time Profiler' --output 'profiling/Promtier_TimeProfiler.trace' --time-limit 8s --launch -- '/Users/valencia/Library/Developer/Xcode/DerivedData/Promtier-gwtwqauqniqqumfryffqozcsjphv/Build/Products/Debug/Promtier.app/Contents/MacOS/Promtier'`

## Notes
- Trace artifact exists and can be opened in Instruments for hot-path inspection.
- This repository currently lacks scripted extraction of top symbols from `.trace`; manual review in Instruments remains required for symbol-level ranking.

## Recommended Manual Review Focus
- SwiftUI update/layout time in editor cards while typing.
- PromptImageShowcaseView resize behavior under rapid window width changes.
- Image import/optimization path latency when dropping multiple images.
