import unittest

from app import build_launch_plan


class LaunchPlanTests(unittest.TestCase):
    def test_defaults_are_clean(self) -> None:
        plan = build_launch_plan({"command": "codex"})
        self.assertEqual(plan["command"], "codex")
        self.assertFalse(plan["browser"])
        self.assertFalse(plan["tunnel"])
        self.assertFalse(plan["tray"])
        self.assertFalse(plan["watcher"])

    def test_explicit_watcher_request_is_allowed(self) -> None:
        plan = build_launch_plan({"command": "codex", "watcher": True})
        self.assertTrue(plan["watcher"])


if __name__ == "__main__":
    unittest.main()
