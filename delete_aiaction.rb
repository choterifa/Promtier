require 'fileutils'
content = File.read("Promtier/Views/NewPromptView.swift")
lines = content.lines

target = "enum AIAction {"
start_idx = lines.index { |l| l.include?(target) }
if start_idx
  brace_count = 0
  end_idx = start_idx
  lines[start_idx..-1].each_with_index do |line, i|
    brace_count += line.count('{')
    brace_count -= line.count('}')
    if brace_count == 0 && i > 0
      end_idx = start_idx + i
      break
    end
  end
  lines.slice!(start_idx..end_idx)
  puts "Deleted AIAction"
end

File.write("Promtier/Views/NewPromptView.swift", lines.join)
