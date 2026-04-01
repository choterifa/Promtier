content = File.read("Promtier/Views/NewPromptView.swift")

# Restore func title
content.sub!(/func viewModel\.title\(for promptTitle:/, "func title(for promptTitle:")
# Restore case title
content.sub!(/case viewModel\.title = "Título"/, "case title = \"Título\"")
# Restore any properties like let title1 etc.
content.gsub!(/let viewModel\.title1/, "let title1")
content.gsub!(/let viewModel\.title2/, "let title2")
content.gsub!(/var viewModel\.title1/, "var title1")
content.gsub!(/var viewModel\.title2/, "var title2")

File.write("Promtier/Views/NewPromptView.swift", content)
