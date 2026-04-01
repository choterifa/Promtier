require 'fileutils'
content = File.read("Promtier/Views/NewPromptView.swift")
lines = content.lines

start_idx = lines.index { |l| l.include?("struct EditorCard: View {") }
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
  lines.slice!(start_idx..end_idx)
  File.write("Promtier/Views/NewPromptView.swift", lines.join)
  puts "Deleted EditorCard length #{end_idx - start_idx + 1}"
end
