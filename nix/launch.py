#!/usr/bin/env python3
"""
Nix Package Builder & Launcher for Noctalia.

Workflow:
1. Start 'nix build --no-link --print-out-paths nixpkgs#<pkg>'
2. Stream build/download progress lines to desktop notifications via notify-send.
3. Discover all .desktop files produced in the store output path(s).
4. - If exactly 1 desktop file: launch it directly.
   - If >1 desktop files: prompt the user with a menu (noctalia dmenu / rofi)
     showing extracted Name as title and .desktop filename as subtitle.
   - If 0 desktop files: fall back to 'nix run nixpkgs#<pkg>'.
"""

import sys
import os
import re
import time
import shutil
import threading
import subprocess

def send_notification(summary, body, replace_id=None, urgency="normal"):
    """Send or update a desktop notification via notify-send."""
    cmd = ["notify-send", "-a", "Nix Launcher", "-i", "package"]
    if urgency != "normal":
        cmd.extend(["-u", urgency])
    if replace_id:
        cmd.extend(["-r", str(replace_id)])
    else:
        cmd.append("-p")

    cmd.extend([summary, body])
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, check=False)
        if not replace_id and res.returncode == 0:
            out = res.stdout.strip()
            if out.isdigit():
                return int(out)
    except Exception:
        pass
    return replace_id

def parse_desktop_entry(path):
    """Parse Name, Exec, Terminal, and Path from [Desktop Entry] section."""
    name = None
    exec_cmd = None
    terminal = False
    working_dir = None

    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            in_section = False
            for line in f:
                line = line.strip()
                if line == "[Desktop Entry]":
                    in_section = True
                elif line.startswith("[") and line.endswith("]"):
                    in_section = False
                elif in_section:
                    if line.startswith("Name=") and name is None:
                        name = line[5:].strip()
                    elif line.startswith("Exec=") and exec_cmd is None:
                        exec_cmd = line[5:].strip()
                    elif line.startswith("Terminal="):
                        terminal = line[9:].strip().lower() in ("true", "1")
                    elif line.startswith("Path=") and working_dir is None:
                        working_dir = line[5:].strip()
    except Exception:
        pass

    return name, exec_cmd, terminal, working_dir

def launch_desktop_file(desktop_path, store_paths):
    """Launch an application from its .desktop file."""
    name, exec_cmd, terminal, working_dir = parse_desktop_entry(desktop_path)

    env = os.environ.copy()
    bin_dirs = [os.path.join(p, "bin") for p in store_paths if os.path.isdir(os.path.join(p, "bin"))]
    if bin_dirs:
        env["PATH"] = ":".join(bin_dirs) + ":" + env.get("PATH", "")

    cwd = working_dir if (working_dir and os.path.isdir(working_dir)) else os.path.expanduser("~")

    if not exec_cmd:
        # Fallback to dex or gtk-launch if available
        if shutil.which("dex"):
            subprocess.Popen(["dex", desktop_path], env=env, cwd=cwd, preexec_fn=os.setsid,
                             stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return
        elif shutil.which("gtk-launch"):
            desktop_name = os.path.basename(desktop_path)
            subprocess.Popen(["gtk-launch", desktop_name], env=env, cwd=cwd, preexec_fn=os.setsid,
                             stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return

    # Strip field codes (%f, %F, %u, %U, %d, %D, %n, %N, %i, %c, %k, %v, %m)
    clean_cmd = re.sub(r"%[fFuUdDnNikvm]", "", exec_cmd).strip()

    if terminal:
        term = env.get("TERMINAL") or shutil.which("konsole") or shutil.which("xterm") or "xterm"
        if "konsole" in term:
            full_cmd = [term, "-e", "bash", "-c", clean_cmd]
        else:
            full_cmd = [term, "-e", "sh", "-c", clean_cmd]
    else:
        full_cmd = ["sh", "-c", clean_cmd]

    subprocess.Popen(
        full_cmd,
        env=env,
        cwd=cwd,
        preexec_fn=os.setsid,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )

def launch_nix_run(pkg):
    """Fallback: launch package using 'nix run'."""
    cmd = ["nix", "run", f"nixpkgs#{pkg}"]
    subprocess.Popen(
        cmd,
        preexec_fn=os.setsid,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )

def prompt_user_selection(pkg, desktop_files):
    """Show another menu with name extracted from each and the desktop file as subtitle."""
    choices = []
    mapping = {}

    for df in desktop_files:
        name, _, _, _ = parse_desktop_entry(df)
        basename = os.path.basename(df)
        display_name = name if name else basename.replace(".desktop", "")

        # Format: <Title>\t<Subtitle>
        entry_key = f"{display_name}\t{basename}"
        choices.append(entry_key)
        mapping[entry_key] = df
        mapping[display_name] = df
        mapping[basename] = df

    input_text = "\n".join(choices) + "\n"
    selected = None

    # Try noctalia dmenu first
    if shutil.which("noctalia"):
        try:
            res = subprocess.run(
                ["noctalia", "dmenu", "-p", f"Launch {pkg}"],
                input=input_text,
                capture_output=True,
                text=True,
                check=False
            )
            if res.returncode == 0:
                selected = res.stdout.strip()
        except Exception:
            pass

    # Fallback to rofi if noctalia dmenu didn't return a choice
    if not selected and shutil.which("rofi"):
        try:
            res = subprocess.run(
                ["rofi", "-dmenu", "-p", f"Launch {pkg}"],
                input=input_text,
                capture_output=True,
                text=True,
                check=False
            )
            if res.returncode == 0:
                selected = res.stdout.strip()
        except Exception:
            pass

    if not selected:
        return None

    # Find the corresponding desktop file
    if selected in mapping:
        return mapping[selected]

    for k, df in mapping.items():
        if selected in k or k in selected:
            return df

    return None

def main():
    if len(sys.argv) < 2:
        print("Usage: launch.py <package_name>", file=sys.stderr)
        sys.exit(1)

    pkg = sys.argv[1].strip()
    if not pkg:
        sys.exit(0)

    # 1. Start notification
    notif_id = send_notification(
        f"Nix: Building {pkg}",
        f"Starting nix build for nixpkgs#{pkg}..."
    )

    # 2. Run 'nix build --no-link --print-out-paths nixpkgs#<pkg>'
    cmd = ["nix", "build", "--no-link", "--print-out-paths", f"nixpkgs#{pkg}"]
    proc = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1
    )

    stdout_lines = []
    stderr_lines = []
    last_notify_time = [0.0]

    def on_progress_line(line):
        now = time.time()
        # Rate limit notification updates to at most ~4 per second
        if (now - last_notify_time[0]) >= 0.25:
            last_notify_time[0] = now
            send_notification(f"Nix: Building {pkg}", line, replace_id=notif_id)

    def read_stderr():
        buf = []
        while True:
            ch = proc.stderr.read(1)
            if not ch:
                break
            if ch in ("\r", "\n"):
                line = "".join(buf).strip()
                buf = []
                if line:
                    stderr_lines.append(line)
                    on_progress_line(line)
            else:
                buf.append(ch)
        if buf:
            line = "".join(buf).strip()
            if line:
                stderr_lines.append(line)
                on_progress_line(line)

    def read_stdout():
        for line in proc.stdout:
            stdout_lines.append(line.strip())

    t_err = threading.Thread(target=read_stderr)
    t_out = threading.Thread(target=read_stdout)
    t_err.start()
    t_out.start()

    proc.wait()
    t_err.join()
    t_out.join()

    # Check build result
    if proc.returncode != 0:
        error_msg = stderr_lines[-1] if stderr_lines else "Build failed with non-zero exit code"
        send_notification(
            f"Nix: Build failed for {pkg}",
            error_msg,
            replace_id=notif_id,
            urgency="critical"
        )
        sys.exit(proc.returncode)

    # Successful build!
    store_paths = [p for p in stdout_lines if p and os.path.exists(p)]

    # 3. Find all .desktop files in that package
    desktop_files = []
    for out_path in store_paths:
        apps_dir = os.path.join(out_path, "share", "applications")
        if os.path.isdir(apps_dir):
            for root, _, files in os.walk(apps_dir):
                for f in files:
                    if f.endswith(".desktop"):
                        desktop_files.append(os.path.join(root, f))

        if not desktop_files:
            for root, _, files in os.walk(out_path):
                for f in files:
                    if f.endswith(".desktop"):
                        desktop_files.append(os.path.join(root, f))

    # Deduplicate desktop files while preserving order
    unique_desktop_files = []
    seen = set()
    for df in desktop_files:
        if df not in seen:
            seen.add(df)
            unique_desktop_files.append(df)
    desktop_files = unique_desktop_files

    # 4. Launch logic
    if len(desktop_files) == 1:
        name, _, _, _ = parse_desktop_entry(desktop_files[0])
        app_title = name if name else pkg
        send_notification(f"Nix: Built {pkg}", f"Launching {app_title}...", replace_id=notif_id)
        launch_desktop_file(desktop_files[0], store_paths)
    elif len(desktop_files) > 1:
        send_notification(f"Nix: Built {pkg}", f"Found {len(desktop_files)} applications. Please choose one...", replace_id=notif_id)
        chosen = prompt_user_selection(pkg, desktop_files)
        if chosen:
            name, _, _, _ = parse_desktop_entry(chosen)
            app_title = name if name else pkg
            send_notification(f"Nix: Launching", f"Starting {app_title}...", replace_id=notif_id)
            launch_desktop_file(chosen, store_paths)
    else:
        send_notification(f"Nix: Built {pkg}", f"No .desktop files found. Running nix run...", replace_id=notif_id)
        launch_nix_run(pkg)

if __name__ == "__main__":
    main()
