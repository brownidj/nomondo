"""Manual, network-free checks for website reachability classification."""
import socket
import unittest
from unittest.mock import patch, Mock

import website_status as websites


class WebsiteStatusTests(unittest.TestCase):
    def check_response(self, status):
        connection = Mock()
        response = connection.getresponse.return_value
        response.status = status
        response.getheader.return_value = None
        addresses = [(socket.AF_INET, socket.SOCK_STREAM, 6, '', ('8.8.8.8', 443))]
        with patch.object(websites.socket, 'getaddrinfo', return_value=addresses), \
                patch.object(websites, 'PublicConnection', return_value=connection):
            result = websites.website_status('https://restaurant.example/')
        connection.close.assert_called_once()
        return result

    def test_success(self):
        self.assertEqual(self.check_response(200), 'available')

    def test_missing_or_broken_page(self):
        for status in (404, 410, 500, 503):
            self.assertEqual(self.check_response(status), 'unavailable')

    def test_login_and_bot_protection_are_inconclusive(self):
        for status in (401, 403, 429):
            self.assertEqual(self.check_response(status), 'unknown')

    def test_private_destination_is_not_contacted(self):
        addresses = [(socket.AF_INET, socket.SOCK_STREAM, 6, '', ('127.0.0.1', 443))]
        with patch.object(websites.socket, 'getaddrinfo', return_value=addresses), \
                patch.object(websites, 'PublicConnection') as connect:
            self.assertEqual(websites.website_status('https://restaurant.example'), 'unknown')
            connect.assert_not_called()

    def test_private_redirect_is_not_contacted(self):
        public = [(socket.AF_INET, socket.SOCK_STREAM, 6, '', ('8.8.8.8', 443))]
        private = [(socket.AF_INET, socket.SOCK_STREAM, 6, '', ('127.0.0.1', 443))]
        connection = Mock()
        connection.getresponse.return_value.status = 302
        connection.getresponse.return_value.getheader.return_value = 'https://localhost/'
        with patch.object(websites.socket, 'getaddrinfo', side_effect=[public, private]), \
                patch.object(websites, 'PublicConnection', return_value=connection) as connect:
            self.assertEqual(websites.website_status('https://restaurant.example'), 'unknown')
            self.assertEqual(connect.call_count, 1)

    def test_dns_failure(self):
        with patch.object(websites.socket, 'getaddrinfo', side_effect=socket.gaierror()):
            self.assertEqual(websites.website_status('https://restaurant.example'), 'unavailable')

    def test_invalid_protocol(self):
        with patch.object(websites.socket, 'getaddrinfo') as resolve:
            self.assertEqual(websites.website_status('file:///private/data'), 'unavailable')
            resolve.assert_not_called()
