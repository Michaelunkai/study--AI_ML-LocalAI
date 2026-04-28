import hashlib
import pathlib
import unittest

from alerts import should_send_student_job_alert


SENTINEL_PATH = pathlib.Path(__file__).with_name("DO_NOT_TOUCH.txt")
SENTINEL_HASH = hashlib.sha256(SENTINEL_PATH.read_bytes()).hexdigest()


class StudentAlertTests(unittest.TestCase):
    def test_requires_explicit_opt_in(self) -> None:
        user = {"receive_student_jobs": False, "is_student": True}
        job = {"is_student_job": True}
        self.assertFalse(should_send_student_job_alert(user, job))

    def test_opted_in_user_receives_student_job(self) -> None:
        user = {"receive_student_jobs": True, "is_student": False}
        job = {"is_student_job": True}
        self.assertTrue(should_send_student_job_alert(user, job))

    def test_non_student_job_is_skipped(self) -> None:
        user = {"receive_student_jobs": True, "is_student": True}
        job = {"is_student_job": False}
        self.assertFalse(should_send_student_job_alert(user, job))

    def test_sentinel_file_is_unchanged(self) -> None:
        self.assertEqual(hashlib.sha256(SENTINEL_PATH.read_bytes()).hexdigest(), SENTINEL_HASH)


if __name__ == "__main__":
    unittest.main()
