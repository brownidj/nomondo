"""Local, read-only JSON service for the BeneEde Flutter interface."""
from __future__ import annotations

import argparse
import errno
import os
import signal
from contextlib import closing
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import sqlite3

import psutil
from urllib.parse import urlsplit

from phone_numbers import format_telephone

ROOT = Path(__file__).resolve().parent
LIST_FIELDS = (
    'id', 'restaurant_name', 'city', 'country', 'address', 'cuisine', 'special_dish',
    'notes', 'telephone', 'internet_link', 'needs_review',
)


def read_restaurants(database: Path) -> list[dict]:
    # mode=ro prevents accidental writes and refuses to create a missing database.
    with closing(sqlite3.connect(database.resolve().as_uri() + '?mode=ro', uri=True, timeout=5)) as db:
        db.row_factory = sqlite3.Row
        rows = db.execute(f"SELECT {','.join(LIST_FIELDS)} FROM restaurants "
                          "ORDER BY restaurant_name COLLATE NOCASE, city COLLATE NOCASE, id")
        restaurants = [dict(row) for row in rows]
        for restaurant in restaurants:
            restaurant['telephone'] = format_telephone(restaurant['telephone'], restaurant['country'])
        return restaurants


class RestaurantServer(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True

    def __init__(self, port: int, database: Path):
        self.database = database
        super().__init__(('127.0.0.1', port), RestaurantHandler)


class RestaurantHandler(BaseHTTPRequestHandler):
    server: RestaurantServer

    def origin_allowed(self) -> bool:
        origin = self.headers.get('Origin')
        if not origin:
            return True
        try:
            parsed = urlsplit(origin)
            return (parsed.scheme in {'http', 'https'}
                    and parsed.hostname in {'localhost', '127.0.0.1', '::1'})
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
            self.send_header('Access-Control-Allow-Methods', 'GET, OPTIONS')
        self.end_headers()
        if body:
            self.wfile.write(body)

    def do_OPTIONS(self):
        self.respond(204 if self.origin_allowed() else 403)

    def do_GET(self):
        if not self.origin_allowed():
            self.respond(403, {'error': 'Only local browser origins are allowed'})
            return
        if urlsplit(self.path).path != '/api/restaurants':
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
    options = {'--port': '8765', '--db': str(ROOT / 'data' / 'restaurants.sqlite3')}
    args = args[1:]
    while args:
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
                       and connection.laddr.ip == '127.0.0.1'
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


def start_server(port: int, database: Path) -> RestaurantServer:
    # Binding is the port check: a separate probe would introduce a race.
    try:
        return RestaurantServer(port, database)
    except OSError as error:
        if error.errno != errno.EADDRINUSE:
            raise
        if not release_previous_service(port, database):
            raise RuntimeError(
                f'Port {port} is occupied by another program or an unverified service. '
                f'Close that program, or use --port {port + 1 if port < 65535 else 8765} '
                'and set Flutter RESTAURANT_API_URL to the same port.') from None
    return RestaurantServer(port, database)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--db', type=Path, default=ROOT / 'data' / 'restaurants.sqlite3')
    parser.add_argument('--port', type=int, default=8765)
    args = parser.parse_args()
    if not args.db.is_file():
        parser.error('Database does not exist; import restaurant data first')
    if not 1 <= args.port <= 65535:
        parser.error('--port must be between 1 and 65535')
    try:
        server = start_server(args.port, args.db)
    except (OSError, RuntimeError) as error:
        parser.exit(1, f'Could not start the local service: {error}\n')
    print(f'BeneEde data service: http://127.0.0.1:{args.port}/api/restaurants', flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == '__main__':
    main()
