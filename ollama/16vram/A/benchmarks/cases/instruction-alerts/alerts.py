def should_send_student_job_alert(user, job):
    if not job.get("is_student_job"):
        return False

    return bool(user.get("receive_student_jobs") or user.get("is_student"))
