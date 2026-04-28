import unittest

from slugify import normalize_issue_title


class NormalizeIssueTitleTests(unittest.TestCase):
    def test_trims_and_cleans(self) -> None:
        self.assertEqual(
            normalize_issue_title(" API v2 / Login_fix!!! "),
            "api-v2-login-fix",
        )

    def test_collapses_mixed_separators(self) -> None:
        self.assertEqual(
            normalize_issue_title("student__jobs---opt in"),
            "student-jobs-opt-in",
        )

    def test_returns_empty_for_none(self) -> None:
        self.assertEqual(normalize_issue_title(None), "")


if __name__ == "__main__":
    unittest.main()
