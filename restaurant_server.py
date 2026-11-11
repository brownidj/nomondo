"""Local restaurant browsing and editing service for the BeneEde Flutter interface."""
from __future__ import annotations

import argparse
import errno
import os
import re
import signal
import hmac
import hashlib
import ipaddress
import socket
from contextlib import closing
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import sqlite3

import psutil
from urllib.parse import urlsplit, parse_qs

from restaurant_edits import EditError, public_record, save_edit, delete_record
from website_status import website_status
from beneede import connect
from restaurant_lookup import LookupManager
from restaurant_additions import create_records
from city_index import suggest_cities, DEFAULT_INDEX, ATTRIBUTION
from restaurant_reviews import read_review, save_review, read_offline_catalogue
from mobile_connection import ensure_mobile_connection

ROOT = Path(__file__).resolve().parent


def read_restaurants(database: Path) -> list[dict]:
    # mode=ro prevents accidental writes and refuses to create a missing database.
    with closing(sqlite3.connect(database.resolve().as_uri() + '?mode=ro', uri=True, timeout=5)) as db:
        db.row_factory = sqlite3.Row
        rows = db.execute("SELECT * FROM restaurants "
                          "ORDER BY restaurant_name COLLATE NOCASE, city COLLATE NOCASE, id")
        return [public_record(row) for row in rows]


class RestaurantServer(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True

    def __init__(self, port: int, database: Path, lan=False):
        self.database = database
        config = ensure_mobile_connection(port) if lan else {}
        self.access_token = config.get('RESTAURANT_API_TOKEN')
        self.allowed_hosts = {'localhost', '127.0.0.1', '::1'}
        if lan:
            self.allowed_hosts.add(urlsplit(config['RESTAURANT_API_URL']).hostname.lower())
            for addresses in psutil.net_if_addrs().values():
                self.allowed_hosts.update(address.address.lower() for address in addresses
                                          if address.family == socket.AF_INET)
        with closing(connect(database)):
            pass  # Apply additive schema changes before publishing record revisions.
        self.lookups = LookupManager()
        super().__init__(('0.0.0.0' if lan else '127.0.0.1', port), RestaurantHandler)


class RestaurantHandler(BaseHTTPRequestHandler):
    server: RestaurantServer

    def request_authorized(self):
        try:
            peer = ipaddress.ip_address(self.client_address[0])
        except (ValueError, AttributeError):
            return False
        if peer.is_loopback:
            return True
        token = getattr(self.server, 'access_token', None)
        supplied = self.headers.get('Authorization', '')
        return bool(peer.is_private and token and hmac.compare_digest(supplied.encode(), ('Bearer ' + token).encode()))

    def origin_allowed(self) -> bool:
        origin = self.headers.get('Origin')
        if not origin:
            return True
        try:
            parsed = urlsplit(origin)
            return (parsed.scheme in {'http', 'https'}
                    and parsed.hostname in getattr(getattr(self, 'server', None), 'allowed_hosts', {'localhost', '127.0.0.1', '::1'}))
        except ValueError:
            return False

    def respond(self, status: int, payload=None):
        body = json.dumps(payload, ensure_ascii=False).encode('utf-8') if payload is not None else b''
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Cache-Control', 'no-store')
        self.send_header('Vary', 'Origin')
        origin = self.headers.get('Origin')
        if origin and self.origin_allowed():
            self.send_header('Access-Control-Allow-Origin', origin)
            self.send_header('Access-Control-Allow-Methods', 'GET, POST, PATCH, DELETE, OPTIONS')
            self.send_header('Access-Control-Allow-Headers', 'Content-Type, X-BeneEde-Edit, Authorization')
        self.end_headers()
        if body:
            self.wfile.write(body)

    def do_OPTIONS(self):
        self.respond(204 if self.origin_allowed() else 403)

    def do_POST(self):
        self._write_restaurant(deleting=False, creating=True)

    def do_DELETE(self):
        self._write_restaurant(deleting=True)

    def do_PATCH(self):
        self._write_restaurant(deleting=False)

    def _write_restaurant(self, deleting, creating=False):
        try:
            host = urlsplit('http://' + self.headers.get('Host', '')).hostname
        except ValueError:
            host = None
        if not self.origin_allowed() or host not in getattr(getattr(self, 'server', None), 'allowed_hosts', {'localhost', '127.0.0.1', '::1'}):
            self.respond(403, {'error': 'Only local edits are allowed'})
            return
        if not self.request_authorized():
            self.respond(401, {'error': 'This device is not paired with the catalogue service.'})
            return
        path = urlsplit(self.path).path
        if path == '/api/restaurant-lookups' and not ipaddress.ip_address(self.client_address[0]).is_loopback:
            self.respond(403, {'error': 'Automatic discovery is available on the Mac only.'})
            return
        match = re.fullmatch(r'/api/restaurants/(\d+)', path)
        review = re.fullmatch(r'/api/restaurants/(\d+)/review', path) if creating else None
        if (creating and not review and path not in {'/api/restaurants', '/api/restaurant-lookups'}) or (not creating and not match):
            self.respond(404, {'error': 'Not found'})
            return
        if (self.headers.get('Content-Type', '').split(';')[0].lower() != 'application/json'
                or self.headers.get('X-BeneEde-Edit') != '1'):
            self.respond(400, {'error': 'Expected a JSON edit request'})
            return
        try:
            length = int(self.headers.get('Content-Length', '0'))
            if not 0 < length <= 262144:
                self.respond(413, {'error': 'Edit is empty or too large'})
                return
            payload = json.loads(self.rfile.read(length))
            if review:
                expected = {'revision', 'decision', 'note'}
            elif creating:
                expected = ({'request_id', 'fields', 'mode'} if path == '/api/restaurant-lookups'
                            else {'request_id', 'records', 'lookup_id'})
            else:
                expected = {'revision', 'confirmed'} if deleting else {'revision', 'changes'}
            if not isinstance(payload, dict) or set(payload) != expected:
                raise EditError(400, 'Invalid edit request')
            if review:
                result = save_review(self.server.database, int(review[1]), payload['revision'], payload['decision'], payload['note'])
                self.respond(200, {'restaurant': result})
            elif creating:
                if path == '/api/restaurant-lookups':
                    result = self.server.lookups.start(payload['request_id'], payload['fields'], payload['mode'])
                    self.respond(202, result)
                else:
                    result = create_records(self.server.database, payload['request_id'], payload['records'],
                                            payload['lookup_id'], self.server.lookups.result)
                    self.respond(200, result)
            elif deleting:
                if payload['confirmed'] is not True:
                    raise EditError(400, 'Deletion must be confirmed.')
                delete_record(self.server.database, int(match[1]), payload['revision'])
                self.respond(200, {'deleted_id': int(match[1])})
            else:
                result = save_edit(self.server.database, int(match[1]), payload['revision'], payload['changes'])
                self.respond(200, {'restaurant': result})
        except EditError as error:
            self.respond(error.status, {'error': str(error)})
        except (ValueError, UnicodeError):
            self.respond(400, {'error': 'Invalid JSON edit request'})
        except sqlite3.Error:
            self.respond(503, {'error': 'Could not update the record. No changes were applied; try again.'})

    def do_GET(self):
        if not self.origin_allowed():
            self.respond(403, {'error': 'Only local browser origins are allowed'})
            return
        path = urlsplit(self.path).path
        if path == '/api/server-proof':
            token = getattr(self.server, 'access_token', None)
            try:
                private_peer = ipaddress.ip_address(self.client_address[0]).is_private
                challenge = parse_qs(urlsplit(self.path).query, max_num_fields=1).get('challenge', [''])[0]
                if not private_peer or not token or not re.fullmatch(r'[a-f0-9]{32}', challenge):
                    self.respond(400, {'error': 'Invalid server identity request.'})
                    return
                proof = hmac.new(token.encode(), ('beneede-server:' + challenge).encode(), hashlib.sha256).hexdigest()
                self.respond(200, {'service': 'BeneEde', 'proof': proof})
            except ValueError:
                self.respond(400, {'error': 'Invalid server identity request.'})
            return
        if not self.request_authorized():
            self.respond(401, {'error': 'This device is not paired with the catalogue service.'})
            return
        if path == '/api/health':
            token = getattr(self.server, 'access_token', None)
            self.respond(200, {'service': 'BeneEde', 'pid': os.getpid(), 'mobile_access': bool(token),
                               'pairing_fingerprint': hashlib.sha256(token.encode()).hexdigest()[:16] if token else None})
            return
        if path == '/api/offline-catalogue':
            try:
                params = parse_qs(urlsplit(self.path).query, max_num_fields=1)
                version = params.get('version', [''])[0]
                self.respond(200, read_offline_catalogue(self.server.database, version))
            except ValueError:
                self.respond(400, {'error': 'Invalid snapshot request.'})
            except sqlite3.Error:
                self.respond(503, {'error': 'The offline catalogue is temporarily unavailable.'})
            return
        review = re.fullmatch(r'/api/restaurants/(\d+)/review', path)
        if review:
            try:
                self.respond(200, read_review(self.server.database, int(review[1])))
            except EditError as error:
                self.respond(error.status, {'error': str(error)})
            except sqlite3.Error:
                self.respond(503, {'error': 'Review details are temporarily unavailable.'})
            return
        if path == '/api/cities':
            try:
                params = parse_qs(urlsplit(self.path).query, max_num_fields=5)
                query = params.get('q', [''])[0]
                country = params.get('country', [''])[0]
                if len(query) > 80 or len(country) > 120:
                    raise ValueError('City search is too long.')
                self.respond(200, {'cities': suggest_cities(query, country),
                                   'available': DEFAULT_INDEX.exists(), 'attribution': ATTRIBUTION})
            except ValueError:
                self.respond(400, {'error': 'Invalid city search.'})
            except sqlite3.Error:
                self.respond(503, {'error': 'City suggestions are unavailable; enter the city manually.'})
            return
        lookup = re.fullmatch(r'/api/restaurant-lookups/([A-Za-z0-9_-]{8,100})', path)
        if lookup:
            try:
                self.respond(200, self.server.lookups.get(lookup[1]))
            except EditError as error:
                self.respond(error.status, {'error': str(error)})
            return
        website = re.fullmatch(r'/api/restaurants/(\d+)/website-status', path)
        if website:
            try:
                with closing(sqlite3.connect(self.server.database.resolve().as_uri() + '?mode=ro', uri=True)) as db:
                    row = db.execute('SELECT internet_link FROM restaurants WHERE id=?', (int(website[1]),)).fetchone()
                if row is None:
                    self.respond(404, {'error': 'Restaurant not found'})
                else:
                    self.respond(200, {'status': website_status(row[0])})
            except sqlite3.Error:
                self.respond(503, {'error': 'Restaurant data is temporarily unavailable'})
            return
        if path != '/api/restaurants':
            self.respond(404, {'error': 'Not found'})
            return
        try:
            restaurants = read_restaurants(self.server.database)
        except sqlite3.Error:
            self.respond(503, {'error': 'Restaurant data is temporarily unavailable'})
            return
        self.respond(200, {'restaurants': restaurants, 'total': len(restaurants)})


def matches_service(command: list[str], cwd: Path, port: int, database: Path) -> bool:
    """Match an exact Python entry point and its effective port/database."""
    if not command or not Path(command[0]).name.lower().startswith('python'):
        return False
    args = command[1:]
    while args and args[0] in {'-u', '-B', '-E', '-s', '-S', '-I'}:
        args = args[1:]
    if not args or (cwd / args[0]).resolve() != Path(__file__).resolve():
        return False
    # Parse conservatively; unrecognized invocations must never be stopped.
    options = {'--port': '8766' if '--lan' in args else '8765', '--db': str(ROOT / 'data' / 'restaurants.sqlite3')}
    args = args[1:]
    while args:
        if args[0] == '--lan':
            args = args[1:]
            continue
        option, separator, value = args[0].partition('=')
        if option not in options:
            return False
        if not separator:
            if len(args) < 2:
                return False
            value = args[1]
        options[option] = value
        args = args[1 if separator else 2:]
    try:
        return (int(options['--port']) == port
                and (cwd / options['--db']).resolve() == database.resolve())
    except (ValueError, OSError):
        return False


def release_previous_service(port: int, database: Path) -> bool:
    """Gracefully stop only this user's matching service actually listening here."""
    username = psutil.Process().username()
    for process in psutil.process_iter(['pid', 'username', 'cmdline', 'cwd']):
        try:
            info = process.info
            if (info['pid'] == os.getpid() or info['username'] != username
                    or not info['cwd'] or not matches_service(
                        info['cmdline'] or [], Path(info['cwd']), port, database)):
                continue
            if not any(connection.status == psutil.CONN_LISTEN
                       and connection.laddr.ip in {'127.0.0.1', '0.0.0.0'}
                       and connection.laddr.port == port
                       for connection in process.net_connections(kind='tcp')):
                continue
            print(f'Stopping previous BeneEde service (PID {process.pid}) on port {port}…', flush=True)
            process.send_signal(signal.SIGINT)
            process.wait(timeout=5)
            return True
        except psutil.NoSuchProcess:
            continue
        except psutil.AccessDenied:
            continue
        except psutil.TimeoutExpired:
            raise RuntimeError('Previous BeneEde service did not stop within 5 seconds; '
                               'stop it in its terminal and try again.') from None
    return False


def start_server(port: int, database: Path, lan=False) -> RestaurantServer:
    # Binding is the port check: a separate probe would introduce a race.
    try:
        return RestaurantServer(port, database, lan=lan)
    except OSError as error:
        if error.errno != errno.EADDRINUSE:
            raise
        if not release_previous_service(port, database):
            raise RuntimeError(
                f'Port {port} is occupied by another program or an unverified service. '
                f'Close that program, or use --port {port + 1 if port < 65535 else 8765} '
                'and set Flutter RESTAURANT_API_URL to the same port.') from None
    return RestaurantServer(port, database, lan=lan)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--db', type=Path, default=ROOT / 'data' / 'restaurants.sqlite3')
    parser.add_argument('--port', type=int)
    parser.add_argument('--lan', action='store_true', help='Enable paired devices on the private local network (default port 8766)')
    args = parser.parse_args()
    args.port = args.port if args.port is not None else (8766 if args.lan else 8765)
    if not args.db.is_file():
        parser.error('Database does not exist; import restaurant data first')
    if not 1 <= args.port <= 65535:
        parser.error('--port must be between 1 and 65535')
    try:
        server = start_server(args.port, args.db, lan=args.lan)
    except (OSError, RuntimeError) as error:
        parser.exit(1, f'Could not start the local service: {error}\n')
    print(f'BeneEde data service: http://127.0.0.1:{args.port}/api/restaurants', flush=True)
    if args.lan:
        print('Paired local-network access enabled. Private build configuration: data/mobile_connection.json', flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == '__main__':
    main()
