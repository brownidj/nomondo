"""On-demand reachability checks for stored restaurant websites."""
from http.client import HTTPConnection, HTTPException
import ipaddress
import socket
import ssl
import time
from urllib.parse import quote, urljoin, urlsplit


class PublicConnection(HTTPConnection):
    """Connect to the already validated IP; don't resolve the host a second time."""
    def __init__(self, host, port, ip, secure, timeout):
        super().__init__(host, port, timeout=timeout)
        self.ip, self.secure = ip, secure

    def connect(self):
        self.sock = socket.create_connection((self.ip, self.port), self.timeout)
        if self.secure:
            try:
                self.sock = ssl.create_default_context().wrap_socket(self.sock, server_hostname=self.host)
            except Exception:
                self.sock.close()
                raise


def website_status(url):
    """Return available/unavailable/unknown, not a browser load guarantee."""
    if not url or url.strip().lower() == 'not listed':
        return 'unknown'
    url = url.strip()
    if '://' not in url:
        url = 'https://' + url
    deadline = time.monotonic() + 12
    try:
        for _ in range(5):
            parsed = urlsplit(url)
            if parsed.scheme not in {'http', 'https'} or not parsed.hostname or parsed.username or parsed.password:
                return 'unavailable'
            host = parsed.hostname.encode('idna').decode('ascii')
            port = parsed.port or (443 if parsed.scheme == 'https' else 80)
            if port not in {80, 443}:
                return 'unknown'
            addresses = socket.getaddrinfo(host, port, type=socket.SOCK_STREAM)
            ips = {entry[4][0] for entry in addresses}
            if not ips or any(not ipaddress.ip_address(ip).is_global for ip in ips):
                return 'unknown'
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                return 'unavailable'
            ip = sorted(ips, key=lambda ip: (':' in ip, ip))[0]
            connection = PublicConnection(host, port, ip, parsed.scheme == 'https', min(4, remaining))
            try:
                path = quote(parsed.path or '/', safe='/%:@!$&\'()*+,;=-._~')
                if parsed.query:
                    path += '?' + quote(parsed.query, safe='/%?:@!$&\'()*+,;=-._~')
                connection.request('GET', path, headers={'User-Agent': 'BeneEde/0.1 website-check', 'Range': 'bytes=0-0'})
                response = connection.getresponse()
                status = response.status
                location = response.getheader('Location')
                if status in {301, 302, 303, 307, 308} and location:
                    url = urljoin(url, location)
                    continue
                if 200 <= status < 300:
                    return 'available'
                # Auth, anti-bot and rate limits do not prove the user's browser will fail.
                if status in {401, 403, 405, 429}:
                    return 'unknown'
                if status in {404, 410} or status >= 500:
                    return 'unavailable'
                return 'unknown'
            finally:
                connection.close()
        return 'unknown'
    except (OSError, HTTPException, ValueError, UnicodeError):
        return 'unavailable'


def fetch_website_page(url):
    """Fetch a bounded public HTML/JSON page with validated redirect destinations."""
    if '://' not in url:
        url = 'https://' + url
    for _ in range(5):
        parsed = urlsplit(url)
        if parsed.scheme not in {'http', 'https'} or not parsed.hostname or parsed.username or parsed.password:
            raise ValueError('Use a public HTTP or HTTPS website.')
        host = parsed.hostname.encode('idna').decode('ascii')
        port = parsed.port or (443 if parsed.scheme == 'https' else 80)
        if port not in {80, 443}:
            raise ValueError('Website lookup supports standard web ports only.')
        ips = {entry[4][0] for entry in socket.getaddrinfo(host, port, type=socket.SOCK_STREAM)}
        if not ips or any(not ipaddress.ip_address(ip).is_global for ip in ips):
            raise ValueError('Website lookup requires a public internet address.')
        ip = sorted(ips, key=lambda ip: (':' in ip, ip))[0]
        connection = PublicConnection(host, port, ip, parsed.scheme == 'https', 8)
        try:
            path = quote(parsed.path or '/', safe='/%:@!$&\'()*+,;=-._~')
            if parsed.query:
                path += '?' + quote(parsed.query, safe='/%?:@!$&\'()*+,;=-._~')
            connection.request('GET', path, headers={'User-Agent': 'BeneEde/0.1 restaurant-lookup', 'Accept-Encoding': 'identity'})
            response = connection.getresponse()
            if response.status in {301, 302, 303, 307, 308} and response.getheader('Location'):
                url = urljoin(url, response.getheader('Location'))
                continue
            if response.status != 200:
                raise ValueError('The website could not be read. You can still add the details manually.')
            content_type = response.getheader('Content-Type', '').lower()
            if not any(kind in content_type for kind in ('text/html', 'application/xhtml', 'application/ld+json', 'application/json')):
                raise ValueError('The website did not return a readable page.')
            data = response.read(1048577)
            if len(data) > 1048576:
                raise ValueError('The website page is too large for automatic lookup.')
            charset = response.headers.get_content_charset() or 'utf-8'
            try:
                text = data.decode(charset, errors='replace')
            except LookupError:
                text = data.decode('utf-8', errors='replace')
            return url, text
        finally:
            connection.close()
    raise ValueError('The website redirected too many times.')
