"""Local, read-only JSON service for the Nomondo Flutter interface."""
from __future__ import annotations

import argparse
from contextlib import closing
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import sqlite3
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parent
LIST_FIELDS = ('id', 'restaurant_name', 'city', 'country', 'cuisine', 'special_dish', 'notes', 'needs_review')


def read_restaurants(database: Path) -> list[dict]:
    # mode=ro prevents accidental writes and refuses to create a missing database.
    with closing(sqlite3.connect(database.resolve().as_uri() + '?mode=ro', uri=True, timeout=5)) as db:
        db.row_factory = sqlite3.Row
        rows = db.execute(f"SELECT {','.join(LIST_FIELDS)} FROM restaurants "
                          "ORDER BY restaurant_name COLLATE NOCASE, city COLLATE NOCASE, id")
        return [dict(row) for row in rows]


class RestaurantServer(ThreadingHTTPServer):
    daemon_threads = True

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
        server = RestaurantServer(args.port, args.db)
    except OSError:
        parser.exit(1, 'Could not open the local port. Check whether the service is already running.\n')
    print(f'Nomondo data service: http://127.0.0.1:{args.port}/api/restaurants', flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == '__main__':
    main()
