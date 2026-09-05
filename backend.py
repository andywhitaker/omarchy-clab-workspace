#!/usr/bin/env python3
"""
Backend helper script for Omarchy Containerlab plugin.
Provides subcommands:
  - get-topologies: Discovers running topologies, node annotations, links, and merged settings.
  - save-settings <json_str>: Saves per-node application settings.
  - launch --app <terminal|browser> --target <command|url>: Launches the configured action.
"""

import sys
import os
import json
import subprocess
import shutil
import re
import shlex

SETTINGS_DIR = os.path.expanduser("~/.config/omarchy/containerlab")
SETTINGS_FILE = os.path.join(SETTINGS_DIR, "settings.json")

def load_settings():
    if os.path.isfile(SETTINGS_FILE):
        try:
            with open(SETTINGS_FILE, "r") as f:
                return json.load(f)
        except Exception:
            return {}
    return {}

def save_settings(data):
    os.makedirs(SETTINGS_DIR, exist_ok=True)
    with open(SETTINGS_FILE, "w") as f:
        json.dump(data, f, indent=2)
    return {"status": "ok"}

def get_default_action(node_name, kind, image, ipv4, ipv6):
    kind_lower = (kind or "").lower()
    img_lower = (image or "").lower()
    name_lower = (node_name or "").lower()
    
    clean_ip = ""
    if ipv4:
        clean_ip = ipv4.split("/")[0]
    elif ipv6:
        clean_ip = ipv6.split("/")[0]

    # Nokia SR Linux
    if kind_lower in ["srl", "nokia_srlinux"] or "srlinux" in img_lower:
        target_host = clean_ip if clean_ip else node_name
        return {
            "default_app": "terminal",
            "default_command": f"ssh -o StrictHostKeyChecking=no admin@{target_host}",
            "default_url": f"https://{target_host}"
        }
    
    # FRR nodes
    if "frr" in img_lower or "frrouting" in img_lower or kind_lower == "frr" or "frr" in name_lower:
        return {
            "default_app": "terminal",
            "default_command": f"docker exec -it {node_name} vtysh",
            "default_url": f"http://{clean_ip}" if clean_ip else "http://localhost"
        }

    # Web service / browser containers
    if any(k in img_lower or k in name_lower for k in ["web", "nginx", "http", "apache", "grafana", "dashboard"]):
        return {
            "default_app": "browser",
            "default_command": f"docker exec -it {node_name} sh",
            "default_url": f"http://{clean_ip}" if clean_ip else "http://localhost"
        }

    # General Linux / Docker containers
    return {
        "default_app": "terminal",
        "default_command": f"docker exec -it {node_name} bash",
        "default_url": f"http://{clean_ip}" if clean_ip else "http://localhost"
    }

def get_topologies():
    user_settings = load_settings()
    
    # Run containerlab inspect
    try:
        proc = subprocess.run(
            ["containerlab", "inspect", "--all", "--format", "json"],
            capture_output=True,
            text=True,
            timeout=10
        )
        if proc.returncode != 0 and not proc.stdout.strip():
            # No topologies or error
            return {"topologies": [], "active_topology": ""}
        clab_output = json.loads(proc.stdout) if proc.stdout.strip() else {}
    except Exception as e:
        return {"topologies": [], "error": str(e)}

    topologies = []

    for lab_name, node_list in clab_output.items():
        if not node_list:
            continue

        first_node = node_list[0]
        abs_lab_path = first_node.get("absLabPath", "")
        lab_dir = os.path.dirname(abs_lab_path) if abs_lab_path else ""

        # 1. Read node annotations
        annotations = {}
        ann_candidates = [
            f"{abs_lab_path}.annotations.json",
            os.path.join(lab_dir, f"{lab_name}.clab.yml.annotations.json"),
            os.path.join(lab_dir, ".annotations.json"),
            os.path.join(lab_dir, f"{lab_name}.annotations.json")
        ]
        for c in ann_candidates:
            if os.path.isfile(c):
                try:
                    with open(c, "r") as af:
                        ann_data = json.load(af)
                        for item in ann_data.get("nodeAnnotations", []):
                            nid = item.get("id")
                            pos = item.get("position", {})
                            if nid and "x" in pos and "y" in pos:
                                annotations[nid] = {"x": float(pos["x"]), "y": float(pos["y"])}
                    break
                except Exception:
                    pass

        # 2. Read links from topology-data.json
        links = []
        td_candidates = [
            os.path.join(lab_dir, f"clab-{lab_name}", "topology-data.json"),
            os.path.join(os.getcwd(), f"clab-{lab_name}", "topology-data.json")
        ]
        for tc in td_candidates:
            if os.path.isfile(tc):
                try:
                    with open(tc, "r") as tf:
                        td = json.load(tf)
                        for l in td.get("links", []):
                            ep = l.get("endpoints", {})
                            a = ep.get("a", {})
                            z = ep.get("z", {})
                            links.append({
                                "a_node": a.get("node", ""),
                                "a_intf": a.get("interface", ""),
                                "z_node": z.get("node", ""),
                                "z_intf": z.get("interface", "")
                            })
                    break
                except Exception:
                    pass

        # 3. Process nodes and fallback positions if missing in annotations
        spines = []
        leafs = []
        others = []
        for n in node_list:
            nname = n.get("name", "")
            if nname in annotations:
                continue
            nl = nname.lower()
            if "spine" in nl or "core" in nl:
                spines.append(nname)
            elif "leaf" in nl or "tor" in nl or "switch" in nl:
                leafs.append(nname)
            else:
                others.append(nname)

        # Fallback coordinate generator for unannotated nodes
        def assign_row(names, y, start_x=200, step_x=140):
            for idx, nm in enumerate(names):
                annotations[nm] = {"x": float(start_x + idx * step_x), "y": float(y)}

        if spines:
            assign_row(spines, 260)
        if leafs:
            assign_row(leafs, 440)
        if others:
            assign_row(others, 600)

        # Compute bounding box
        xs = [pos["x"] for pos in annotations.values()]
        ys = [pos["y"] for pos in annotations.values()]
        min_x = min(xs) if xs else 0.0
        max_x = max(xs) if xs else 1000.0
        min_y = min(ys) if ys else 0.0
        max_y = max(ys) if ys else 600.0

        lab_settings = user_settings.get(lab_name, {})

        processed_nodes = []
        for n in node_list:
            nname = n.get("name", "")
            nkind = n.get("kind", "")
            nimg = n.get("image", "")
            v4 = n.get("ipv4_address", "")
            v6 = n.get("ipv6_address", "")
            cid = n.get("container_id", "")
            state = n.get("state", "running")
            status_text = n.get("status", "")

            defaults = get_default_action(nname, nkind, nimg, v4, v6)
            node_custom = lab_settings.get(nname, {})

            app = node_custom.get("app") or defaults["default_app"]
            command = node_custom.get("command") or defaults["default_command"]
            url = node_custom.get("url") or defaults["default_url"]

            pos = annotations.get(nname, {"x": 500.0, "y": 300.0})

            clean_ip = v4.split("/")[0] if v4 else (v6.split("/")[0] if v6 else "")

            processed_nodes.append({
                "name": nname,
                "lab_name": lab_name,
                "kind": nkind,
                "image": nimg,
                "state": state,
                "status": status_text,
                "ipv4": clean_ip,
                "ipv4_full": v4,
                "ipv6": v6,
                "container_id": cid,
                "x": pos["x"],
                "y": pos["y"],
                "app": app,
                "command": command,
                "url": url,
                "default_app": defaults["default_app"],
                "default_command": defaults["default_command"],
                "default_url": defaults["default_url"]
            })

        topologies.append({
            "name": lab_name,
            "path": abs_lab_path,
            "node_count": len(processed_nodes),
            "link_count": len(links),
            "nodes": processed_nodes,
            "links": links,
            "bounds": {
                "min_x": min_x,
                "max_x": max_x,
                "min_y": min_y,
                "max_y": max_y
            }
        })

    active_name = topologies[0]["name"] if topologies else ""
    return {
        "topologies": topologies,
        "active_topology": active_name
    }

def launch(app_type, target):
    if not target:
        return {"status": "error", "message": "Target is empty"}

    if app_type == "terminal":
        # Launch terminal with command inside special:clab
        if shutil.which("ghostty"):
            subprocess.Popen([
                "ghostty",
                "--class=org.omarchy.clab-terminal",
                "-e", "bash", "-c", target
            ], start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        elif shutil.which("xdg-terminal-exec"):
            subprocess.Popen([
                "xdg-terminal-exec",
                "--app-id=org.omarchy.clab-terminal",
                "bash", "-c", target
            ], start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        elif shutil.which("omarchy-launch-terminal"):
            subprocess.Popen(["omarchy-launch-terminal", "bash", "-c", target], start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        else:
            subprocess.Popen(["x-terminal-emulator", "-e", "bash", "-c", target], start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return {"status": "ok", "app": "terminal", "target": target}

    elif app_type == "browser":
        # Launch web browser
        url = target
        if not re.match(r"^https?://", url):
            url = "http://" + url
        if shutil.which("omarchy-launch-browser"):
            subprocess.Popen(["omarchy-launch-browser", url], start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        elif shutil.which("xdg-open"):
            subprocess.Popen(["xdg-open", url], start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        else:
            subprocess.Popen(["firefox", url], start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return {"status": "ok", "app": "browser", "target": url}

    return {"status": "error", "message": f"Unknown app type: {app_type}"}

def smart_toggle():
    # 1. Check if special:clab is active on any monitor
    try:
        monitors_proc = subprocess.run(["hyprctl", "monitors", "-j"], capture_output=True, text=True, timeout=3)
        monitors = json.loads(monitors_proc.stdout) if monitors_proc.returncode == 0 else []
    except Exception:
        monitors = []

    in_special_clab = False
    for m in monitors:
        sw = m.get("specialWorkspace", {})
        if sw.get("name") == "special:clab":
            in_special_clab = True
            break

    # 2. Check if Containerlab Workspace window is mapped and if terminals are open
    try:
        clients_proc = subprocess.run(["hyprctl", "clients", "-j"], capture_output=True, text=True, timeout=3)
        clients = json.loads(clients_proc.stdout) if clients_proc.returncode == 0 else []
    except Exception:
        clients = []

    clab_window_visible = False
    terminals_open = False
    for c in clients:
        ws = c.get("workspace", {})
        ws_name = ws.get("name", "")
        if ws_name == "special:clab":
            title = c.get("title", "")
            init_title = c.get("initialTitle", "")
            cls = c.get("class", "")
            init_cls = c.get("initialClass", "")
            if "Containerlab Workspace" in title or "Containerlab Workspace" in init_title:
                clab_window_visible = True
            elif "clab-terminal" in cls or "clab-terminal" in init_cls:
                terminals_open = True

    if not in_special_clab:
        # Switch into special:clab
        subprocess.run(["hyprctl", "dispatch", "hl.dsp.workspace.toggle_special(\"clab\")"])
        # Ensure the topology window is summoned/visible
        subprocess.run(["omarchy-shell", "shell", "summon", "awhitaker.containerlab", "{}"])
        return {"status": "ok", "action": "entered_workspace_and_shown"}

    # We are already inside special:clab
    if clab_window_visible:
        if not terminals_open:
            # No terminals running; toggling means leave special:clab
            subprocess.run(["hyprctl", "dispatch", "hl.dsp.workspace.toggle_special(\"clab\")"])
            return {"status": "ok", "action": "exited_workspace"}
        else:
            # Terminals are running; hide the floating topology window so terminals are unobstructed
            subprocess.run(["omarchy-shell", "shell", "hide", "awhitaker.containerlab"])
            return {"status": "ok", "action": "hidden_topology"}
    else:
        # Topology window is hidden; summon it back in front
        subprocess.run(["omarchy-shell", "shell", "summon", "awhitaker.containerlab", "{}"])
        return {"status": "ok", "action": "shown_topology"}

def main():
    if len(sys.argv) < 2:
        print(json.dumps({"error": "No command provided"}))
        sys.exit(1)

    cmd = sys.argv[1]

    if cmd == "get-topologies":
        result = get_topologies()
        print(json.dumps(result))

    elif cmd == "save-settings":
        if len(sys.argv) > 2:
            raw = sys.argv[2]
        else:
            raw = sys.stdin.read()
        try:
            data = json.loads(raw)
            result = save_settings(data)
            print(json.dumps(result))
        except Exception as e:
            print(json.dumps({"status": "error", "message": str(e)}))

    elif cmd == "launch":
        # Parse --app and --target
        app_type = "terminal"
        target = ""
        i = 2
        while i < len(sys.argv):
            if sys.argv[i] == "--app" and i + 1 < len(sys.argv):
                app_type = sys.argv[i+1]
                i += 2
            elif sys.argv[i] == "--target" and i + 1 < len(sys.argv):
                target = sys.argv[i+1]
                i += 2
            else:
                i += 1
        result = launch(app_type, target)
        print(json.dumps(result))

    elif cmd == "smart-toggle":
        result = smart_toggle()
        print(json.dumps(result))

    else:
        print(json.dumps({"error": f"Unknown command {cmd}"}))
        sys.exit(1)

if __name__ == "__main__":
    main()
