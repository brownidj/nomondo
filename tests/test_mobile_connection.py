"""Manual-only tests for paired LAN requests, with no service/app launches."""
from email.message import Message
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch

from mobile_connection import ensure_mobile_connection
from restaurant_server import RestaurantHandler


class MobileConnectionTests(unittest.TestCase):
    def handler(self, peer, token=None):
        handler = object.__new__(RestaurantHandler)
        handler.client_address = (peer, 12345)
        handler.server = SimpleNamespace(access_token='a' * 40, allowed_hosts={'mac.local'})
        handler.headers = Message()
        handler.headers['Host'] = 'mac.local:8766'
        if token is not None:
            handler.headers['Authorization'] = 'Bearer ' + token
        return handler

    def test_private_peer_requires_pairing_and_public_peer_is_rejected(self):
        self.assertFalse(self.handler('192.168.50.20').request_authorized())
        self.assertFalse(self.handler('192.168.50.20', 'wrong').request_authorized())
        self.assertTrue(self.handler('192.168.50.20', 'a' * 40).request_authorized())
        self.assertFalse(self.handler('8.8.8.8', 'a' * 40).request_authorized())
        self.assertTrue(self.handler('127.0.0.1').request_authorized())

    def test_remote_ai_discovery_is_denied_even_when_paired(self):
        handler = self.handler('192.168.50.20', 'a' * 40)
        handler.path = '/api/restaurant-lookups'
        handler.respond = Mock()
        handler.do_POST()
        self.assertEqual(handler.respond.call_args.args[0], 403)

    def test_pairing_configuration_is_private_stable_and_uses_mac_hostname(self):
        with tempfile.TemporaryDirectory() as temporary:
            config = Path(temporary) / 'mobile_connection.json'
            with patch('mobile_connection.CONFIG', config), patch('mobile_connection.subprocess.run',
                    return_value=SimpleNamespace(stdout='Example-Mac\n')):
                first = ensure_mobile_connection()
                second = ensure_mobile_connection()
            self.assertEqual(first, second)
            self.assertEqual(first['RESTAURANT_API_URL'], 'http://Example-Mac.local:8766')
            self.assertGreaterEqual(len(first['RESTAURANT_API_TOKEN']), 32)
            self.assertEqual(config.stat().st_mode & 0o777, 0o600)
