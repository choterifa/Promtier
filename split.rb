content = File.read("Promtier/Views/NewPromptView.swift")

# Inject view model and remove title
content.sub!(/    @EnvironmentObject var menuBarManager: MenuBarManager\n\n    @State private var title = ""\n/, "    @EnvironmentObject var menuBarManager: MenuBarManager\n\n    @StateObject private var viewModel = NewPromptViewModel()\n\n")

# Replace `$title` and `title` in specific components exactly 
content.gsub!(/\$title(?![\w_])/m, "$viewModel.title")
content.gsub!(/(?<![\w_\.])title(?![\w_:])/m, "viewModel.title")

# However, we must be careful with `self.title`, `prompt.title` etc. The negative lookbehind `(?<![\w_\.])` prevents `.title` but does it prevent `self.title`? Yes.
# Wait, `self.title` is commonly used in closures!
# If we change `self.title = ...` to `self.viewModel.title = ...`, we need to handle `self\.title`.
content.gsub!(/self\.title(?![\w_:])/m, "self.viewModel.title")

File.write("Promtier/Views/NewPromptView.swift", content)
