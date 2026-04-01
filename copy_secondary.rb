require 'fileutils'
content = File.read("Promtier/Views/NewPromptView.swift")
lines = content.lines
start_idx = lines.index { |l| l.include?("struct SecondaryEditorCard") }
if start_idx
  brace_count = 0
  end_idx = start_idx
  lines[start_idx..-1].each_with_index do |line, i|
    brace_count += line.count('{')
    brace_count -= line.count('}')
    if brace_count == 0
      end_idx = start_idx + i
      break
    end
  end
  extracted = lines[start_idx..end_idx].join
  File.write("Promtier/Views/SecondaryEditorCard.swift", "import SwiftUI\n\n" + extracted)
  # Now delete it
  lines.slice!(start_idx..end_idx)
  File.write("Promtier/Views/NewPromptView.swift", lines.join)
  puts "Extracted & Deleted SecondaryEditorCard"
end
