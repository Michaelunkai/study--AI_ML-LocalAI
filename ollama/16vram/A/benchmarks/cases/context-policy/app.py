def build_launch_plan(config):
    plan = {
        "command": config.get("command", "codex"),
        "browser": True,
        "tunnel": True,
        "tray": True,
        "watcher": config.get("watcher", False),
    }

    if config.get("fast_mode"):
        plan["watcher"] = True

    return plan
