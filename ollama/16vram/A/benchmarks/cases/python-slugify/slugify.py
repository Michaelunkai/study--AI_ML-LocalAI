import re


def normalize_issue_title(title: str) -> str:
    if title is None:
        return ""

    text = title.lower()
    text = text.replace(" ", "-")
    text = re.sub(r"-+", "-", text)
    return text
