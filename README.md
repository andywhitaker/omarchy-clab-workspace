# Omarchy Containerlab Workspace Plugin

A native [Omarchy](https://omarchy.org/) and Hyprland plugin that integrates [Containerlab](https://containerlab.dev/) network topologies directly into your desktop environment.

It provides a status bar widget, an interactive graphical topology visualizer inside a dedicated private workspace (`special:clab`), and customizable per-node application launching (terminals, SSH, Docker exec, or web browsers).

![Containerlab Omarchy Plugin](https://raw.githubusercontent.com/srl-labs/containerlab/main/docs/images/logo.svg)

---

## Features

- 📊 **Status Bar Widget**:
  - Displays the active topology and running node count (` <count>`).
  - **Left-click**: Smart toggle — summons the topology canvas or switches to the workspace.
  - **Right-click**: Toggles the dedicated `special:clab` workspace directly.

- 🌌 **Dedicated Private Workspace (`special:clab`)**:
  - Keeps all network lab windows isolated from your primary desktop workspaces.
  - Jump in and out instantly with a single shortcut without disrupting your ongoing tasks.

- 🕸️ **Interactive Floating Topology Canvas**:
  - Renders the network topology graph dynamically based on Containerlab YAML files and `.annotations.yaml` coordinates.
  - Displays interconnecting links between nodes and real-time running/stopped status badges.
  - Stays as a floating window centered on top of open terminal windows.
  - Click any node to instantly launch its configured application.

- ⚙️ **Per-Node Application Launcher & Settings**:
  - Automatic defaults based on device type:
    - **Nokia SR Linux**: Terminal with SSH connection (`ssh -l admin <ip>`).
    - **FRRouting (FRR)**: Terminal with vtysh (`docker exec -it <node> vtysh`).
    - **Linux / Other**: Terminal with Docker exec interactive bash shell.
  - Built-in **Settings** tab to customize each node:
    - Choose application type: **Terminal** or **Web Browser**.
    - Customize target command (e.g. `ssh`, `vtysh`, `telnet`, `docker exec`) or Web UI URL (e.g. `http://localhost:8080`).
    - Settings persist in `~/.config/omarchy/containerlab/settings.json`.
    - Auto-refresh protection prevents input overwrite while editing settings.

- 📜 **Scrolling Layout Support (`SUPER + L`)**:
  - Toggle between Hyprland dwindle tiling and scrolling layouts directly within `special:clab` without affecting other workspaces.

---

## Keybindings

| Shortcut | Action |
| :--- | :--- |
| **`SUPER + ALT + C`** | **Smart toggle Containerlab**: Shows/hides floating topology window |
| **`SUPER + ALT + SHIFT + C`** | Toggle `special:clab` workspace visibility |
| **`SUPER + L`** | Toggle workspace layout (dwindle ↔ scrolling) on current workspace |
| **`Esc`** *(inside topology)* | Minimize / hide topology window to reveal terminals behind it |

---

## Installation

### Automatic Install (Recommended)

Clone this repository and run the install script:

```bash
git clone https://github.com/andywhitaker/omarchy-clab-workspace.git ~/Projects/omarchy-clab-workspace
cd ~/Projects/omarchy-clab-workspace
./install.sh
```

The install script automatically:
1. Symlinks the plugin into `~/.config/omarchy/plugins/awhitaker.containerlab`.
2. Validates the plugin manifest against the Omarchy schema.
3. Installs the layout toggle helper to `~/.local/bin/omarchy-hyprland-workspace-layout-toggle`.
4. Adds the necessary window rules to `~/.config/hypr/hyprland.lua`.
5. Adds keybindings to `~/.config/hypr/bindings.lua`.
6. Reloads Hyprland and enables the plugin in `omarchy-shell`.

---

## Manual Configuration Details

If you prefer to configure manually or customize the integration:

### 1. Hyprland Window Rules (`~/.config/hypr/hyprland.lua`)

```lua
-- Containerlab dedicated special workspace rules
o.window({ class = "^org.quickshell$", title = "^Containerlab Workspace$" }, {
  workspace = "special:clab",
  float = true,
  size = { 1280, 760 },
  center = true
})
o.window({ class = "^org.omarchy.clab-terminal$" }, { workspace = "special:clab" })
```

### 2. Hyprland Keybindings (`~/.config/hypr/bindings.lua`)

```lua
o.bind("SUPER + ALT + C", "Toggle Containerlab topology", "python3 " .. os.getenv("HOME") .. "/.config/omarchy/plugins/awhitaker.containerlab/backend.py smart-toggle")
o.bind("SUPER + ALT + SHIFT + C", "Toggle Containerlab workspace", hl.dsp.workspace.toggle_special("clab"))

-- Workspace layout toggle supporting special workspaces (e.g. special:clab)
hl.unbind("SUPER + L")
o.bind("SUPER + L", "Toggle workspace layout", os.getenv("HOME") .. "/.local/bin/omarchy-hyprland-workspace-layout-toggle")
```

---

## Plugin Architecture

```
omarchy-clab-workspace/
├── manifest.json         # Omarchy plugin manifest (panel + bar-widget)
├── BarWidget.qml         # Status bar widget displaying node count
├── Overlay.qml           # Floating window wrapper with tabs and title bar
├── WorkspaceView.qml     # Dynamic canvas visualizer for network topologies
├── SettingsView.qml      # Device launch application configuration UI
├── backend.py            # Python engine: clab inspection, persistence, app launcher
├── bin/
│   └── omarchy-hyprland-workspace-layout-toggle  # Special workspace layout switch
├── install.sh            # Automated installer
├── uninstall.sh          # Uninstaller / rollback script
└── README.md             # Documentation
```

---

## Requirements

- **Omarchy Linux** (Hyprland + `omarchy-shell`)
- **Containerlab** (`containerlab` CLI on PATH or sudo privileges)
- **Docker**
- **Python 3** (with `pyyaml`)

---

## License

MIT
