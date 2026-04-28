import json
import os
import re
import sys
import warnings
from typing import Any, Dict, List
from urllib.parse import parse_qs, urlencode, urljoin, urlparse

warnings.filterwarnings("ignore", message="urllib3 .* doesn't match a supported version!")

import requests
from requests import RequestsDependencyWarning
from bs4 import BeautifulSoup

USER_AGENT = (
    "Mozilla/5.0"
)

warnings.simplefilter("ignore", RequestsDependencyWarning)
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8")


def _normalize_url(url: str) -> str:
    url = (url or "").strip()
    if not url:
        raise ValueError("URL is required.")
    if not re.match(r"^[a-zA-Z][a-zA-Z0-9+.-]*://", url):
        url = "https://" + url
    return url


def _collapse_text(text: str, max_chars: int) -> str:
    collapsed = re.sub(r"\s+", " ", text or "").strip()
    if max_chars > 0 and len(collapsed) > max_chars:
        return collapsed[: max_chars - 3].rstrip() + "..."
    return collapsed


def _dedupe_links(links: List[str], max_links: int) -> List[str]:
    seen = set()
    result = []
    for link in links:
        if not link or link in seen:
            continue
        seen.add(link)
        result.append(link)
        if len(result) >= max_links:
            break
    return result


def _session() -> requests.Session:
    session = requests.Session()
    session.headers.update({
        "User-Agent": USER_AGENT,
        "Accept-Language": "en-US,en;q=0.9",
    })
    return session


def _call_ollama_cloud(endpoint: str, payload: Dict[str, Any]) -> Dict[str, Any]:
    api_key = os.environ.get("OLLAMA_API_KEY", "").strip()
    if not api_key:
        raise RuntimeError("OLLAMA_API_KEY is not set.")
    response = _session().post(
        f"https://ollama.com/api/{endpoint}",
        headers={"Authorization": f"Bearer {api_key}"},
        json=payload,
        timeout=(10, 45),
    )
    response.raise_for_status()
    return response.json()


def _clean_ddg_href(href: str) -> str:
    if not href:
        return ""
    if href.startswith("//"):
        href = "https:" + href
    parsed = urlparse(href)
    if parsed.netloc.endswith("duckduckgo.com") and parsed.path == "/l/":
        uddg = parse_qs(parsed.query).get("uddg", [""])[0]
        if uddg:
            return uddg
    return href


def search_web(payload: Dict[str, Any]) -> Dict[str, Any]:
    query = (payload.get("query") or "").strip()
    if not query:
        raise ValueError("query is required")
    max_results = int(payload.get("max_results") or 5)
    max_results = min(max(max_results, 1), 10)
    site = (payload.get("site") or "").strip()
    final_query = f"site:{site} {query}" if site else query

    def ddg_results(search_query: str) -> List[Dict[str, str]]:
        response = session.get(
            "https://html.duckduckgo.com/html/",
            params={"q": search_query},
            timeout=(10, 45),
        )
        response.raise_for_status()
        soup = BeautifulSoup(response.text, "lxml")
        found = []
        for node in soup.select("div.result"):
            title_node = node.select_one("a.result__a")
            if not title_node:
                continue
            snippet_node = node.select_one(".result__snippet")
            href = _clean_ddg_href(title_node.get("href", ""))
            title = _collapse_text(title_node.get_text(" ", strip=True), 300)
            snippet = _collapse_text(
                snippet_node.get_text(" ", strip=True) if snippet_node else "",
                600,
            )
            if not href:
                continue
            found.append({"title": title, "url": href, "content": snippet})
            if len(found) >= max_results:
                break
        return found

    try:
        result = _call_ollama_cloud(
            "web_search",
            {"query": final_query, "max_results": max_results},
        )
        return {
            "tool": "web_search",
            "provider": "ollama_cloud",
            "query": final_query,
            "results": result.get("results", [])[:max_results],
        }
    except Exception as cloud_error:
        session = _session()
        results = ddg_results(final_query)
        if site and not results:
            results = [
                item for item in ddg_results(query)
                if site.lower() in urlparse(item["url"]).netloc.lower()
            ][:max_results]

        provider = "duckduckgo_html"
        if not results:
            response = session.get(
                "https://www.bing.com/search",
                params={"q": final_query},
                timeout=(10, 45),
            )
            response.raise_for_status()
            soup = BeautifulSoup(response.text, "lxml")
            for node in soup.select("li.b_algo"):
                title_node = node.select_one("h2 a")
                if not title_node:
                    continue
                snippet_node = node.select_one(".b_caption p")
                href = title_node.get("href", "").strip()
                if not href:
                    continue
                results.append(
                    {
                        "title": _collapse_text(title_node.get_text(" ", strip=True), 300),
                        "url": href,
                        "content": _collapse_text(
                            snippet_node.get_text(" ", strip=True) if snippet_node else "",
                            600,
                        ),
                    }
                )
                if len(results) >= max_results:
                    break
            provider = "bing_html"
            if site and not results:
                response = session.get(
                    "https://www.bing.com/search",
                    params={"q": query},
                    timeout=(10, 45),
                )
                response.raise_for_status()
                soup = BeautifulSoup(response.text, "lxml")
                for node in soup.select("li.b_algo"):
                    title_node = node.select_one("h2 a")
                    if not title_node:
                        continue
                    href = title_node.get("href", "").strip()
                    if not href or site.lower() not in urlparse(href).netloc.lower():
                        continue
                    snippet_node = node.select_one(".b_caption p")
                    results.append(
                        {
                            "title": _collapse_text(title_node.get_text(" ", strip=True), 300),
                            "url": href,
                            "content": _collapse_text(
                                snippet_node.get_text(" ", strip=True) if snippet_node else "",
                                600,
                            ),
                        }
                    )
                    if len(results) >= max_results:
                        break

        return {
            "tool": "web_search",
            "provider": provider,
            "query": final_query,
            "results": results,
            "fallback_reason": str(cloud_error),
        }


def fetch_web(payload: Dict[str, Any]) -> Dict[str, Any]:
    url = _normalize_url(payload.get("url") or "")
    max_chars = int(payload.get("max_chars") or 12000)
    max_links = int(payload.get("max_links") or 20)
    max_links = min(max(max_links, 1), 50)

    try:
        result = _call_ollama_cloud("web_fetch", {"url": url})
        return {
            "tool": "web_fetch",
            "provider": "ollama_cloud",
            "url": url,
            "title": result.get("title", ""),
            "content": _collapse_text(result.get("content", ""), max_chars),
            "links": _dedupe_links(result.get("links", []), max_links),
        }
    except Exception as cloud_error:
        session = _session()
        response = session.get(url, timeout=(10, 45))
        response.raise_for_status()
        soup = BeautifulSoup(response.text, "lxml")
        for tag_name in ("script", "style", "noscript"):
            for node in soup.find_all(tag_name):
                node.decompose()
        title = ""
        if soup.title and soup.title.string:
            title = _collapse_text(soup.title.string, 300)
        headings = [
            _collapse_text(node.get_text(" ", strip=True), 300)
            for node in soup.select("h1, h2, h3")[:12]
            if node.get_text(" ", strip=True)
        ]
        text = _collapse_text(soup.get_text("\n", strip=True), max_chars)
        links = _dedupe_links(
            [
                urljoin(response.url, a.get("href", "").strip())
                for a in soup.select("a[href]")
                if a.get("href", "").strip()
            ],
            max_links,
        )
        return {
            "tool": "web_fetch",
            "provider": "python_requests",
            "url": url,
            "final_url": response.url,
            "status_code": response.status_code,
            "content_type": response.headers.get("Content-Type", ""),
            "title": title,
            "headings": headings,
            "content": text,
            "links": links,
            "fallback_reason": str(cloud_error),
        }


def scrape_web_page(payload: Dict[str, Any]) -> Dict[str, Any]:
    url = _normalize_url(payload.get("url") or "")
    selector = (payload.get("selector") or "").strip()
    if not selector:
        raise ValueError("selector is required")
    max_items = int(payload.get("max_items") or 10)
    max_items = min(max(max_items, 1), 50)

    session = _session()
    response = session.get(url, timeout=(10, 45))
    response.raise_for_status()
    soup = BeautifulSoup(response.text, "lxml")
    items = []
    for node in soup.select(selector):
        text = _collapse_text(node.get_text(" ", strip=True), 500)
        href = node.get("href")
        src = node.get("src")
        item = {
            "tag": node.name,
            "text": text,
            "html": _collapse_text(str(node), 1200),
        }
        if href:
            item["href"] = urljoin(response.url, href)
        if src:
            item["src"] = urljoin(response.url, src)
        items.append(item)
        if len(items) >= max_items:
            break

    return {
        "tool": "scrape_web_page",
        "provider": "python_requests",
        "url": url,
        "final_url": response.url,
        "status_code": response.status_code,
        "selector": selector,
        "item_count": len(items),
        "items": items,
    }


def main() -> None:
    if len(sys.argv) < 3:
        raise SystemExit("usage: ola_web_tools.py <mode> <payload-json>")
    mode = sys.argv[1].strip().lower()
    payload = json.loads(sys.argv[2])
    handlers = {
        "search": search_web,
        "fetch": fetch_web,
        "scrape": scrape_web_page,
    }
    if mode not in handlers:
        raise SystemExit(f"unsupported mode: {mode}")
    result = handlers[mode](payload)
    print(json.dumps(result, ensure_ascii=True))


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(
            json.dumps(
                {
                    "error": str(exc),
                    "tool": "ola_web_tools",
                },
                ensure_ascii=True,
            )
        )
        raise
