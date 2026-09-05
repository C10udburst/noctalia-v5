# Developer & Agent Guidelines for noctalia-v5

This repository contains native **Noctalia (v5+)** plugins and desktop extensions (written in Luau, Python, and shell scripts) for the Noctalia Wayland desktop shell.

---

## Noctalia Documentation Reference

> [!TIP]
> Whenever you or future AI agents need to look up Noctalia architecture, configuration schemas, runtime APIs (`noctalia.*`), declarative UI specifications, launcher provider hooks, or IPC commands, **do not attempt to reverse binaries with GDB or browse web dumps**.
>
> Instead, clone the official documentation repository into `/tmp`:
> ```bash
> git clone https://github.com/noctalia-dev/noctalia-docs /tmp/noctalia-docs
> ```
> All documentation pages are stored as clear, easy-to-read Markdown files under `/tmp/noctalia-docs/src/content/docs/`.

---

## Adding New Plugins

1. **Create Plugin Directory**:
   Create a top-level directory for your plugin (e.g. `nix/`, `my-plugin/`).

2. **Define `plugin.toml`**:
   Specify metadata and entry points. E.g.:
   ```toml
   id = "cloudburst/<plugin-name>"
   name = "Human Readable Name"
   version = "1.0.0"
   description = "Plugin description"
   author = "cloudburst"
   license = "MIT"
   plugin_api = 26

   [[launcher_provider]]
   id = "my-provider"
   entry = "launcher.luau"
   prefix = "cmd"
   glyph = "package"
   include_in_global_search = false
   debounce_ms = 80
   ```

3. **Implement Entry Point**:
   - For launcher providers (`launcher.luau`):
     - `function onQuery(text: string)`: Called when user searches. Call `launcher.setResults(text, results)` to return matches.
     - `function onActivate(id: string)`: Called when the user activates an item.
     - Use `noctalia.fuzzyScore(pattern, text)` for native scoring.
     - Use `noctalia.runAsync(...)` for non-blocking process execution.
   - For bar widgets and panels: Implement widget presentation and retained declarative UI.

4. **Register in `catalog.toml`**:
   Add an entry for the plugin to `/catalog.toml`:
   ```toml
   [[plugin]]
   id = "cloudburst/<plugin-name>"
   name = "Human Readable Name"
   version = "1.0.0"
   description = "Plugin description"
   author = "cloudburst"
   license = "MIT"
   plugin_api = 26
   ```

5. **Load & Test in Noctalia**:
   ```bash
   noctalia msg plugins source add local-plugins path $PWD
   noctalia msg plugins update local-plugins
   noctalia msg plugins enable cloudburst/<plugin-name>
   ```

6. **Documentation**:
   - Write a README.md in your plugin directory with usage instructions.
   - Update main README.md with short description.
