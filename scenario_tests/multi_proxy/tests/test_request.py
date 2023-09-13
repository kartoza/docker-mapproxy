import os
import unittest
import requests


# Function to generate URLs based on config_path
class SetupUrl:
    def __init__(self, config_path):
        self.config_path = config_path

    def generate_test_urls(self):
        config_paths = self.config_path.split(',')
        base_url = 'http://0.0.0.0:8080/'
        urls = []
        for path in config_paths:
            url = base_url + path + "/tms/1.0.0/Demo/osm_grid/"
            urls.append(url)
        return urls


class TestMapProxyTile(unittest.TestCase):
    def setUp(self):
        # Set up the base URLs for your MapProxy instances based on config_path
        self.config_path = os.environ.get('config_path', '')
        url_setup = SetupUrl(self.config_path)
        self.base_urls = url_setup.generate_test_urls()

    def test_tile_exists(self):
        # Define the tile coordinates (zoom, x, y)
        zoom_level = 5
        x_coordinate = 34
        y_coordinate = 28

        # Test each base URL
        for base_url in self.base_urls:
            # Construct the tile URL

            tile_url = f'{base_url}{zoom_level}/{x_coordinate}/{y_coordinate}.png'

            # Send a GET request to the tile URL
            response = requests.get(tile_url)

            # Check if the response status code is 200 (OK)
            self.assertEqual(response.status_code, 200)

    def test_nonexistent_tile(self):
        # Define coordinates for a non-existent tile
        zoom_level = 5
        x_coordinate = 9999
        y_coordinate = 9999

        # Test each base URL
        for base_url in self.base_urls:
            # Construct the URL for the non-existent tile
            tile_url = f'{base_url}{zoom_level}/{x_coordinate}/{y_coordinate}.png'

            # Send a GET request to the tile URL
            response = requests.get(tile_url)

            # Check if the response status code is 404 (Not Found)
            self.assertEqual(response.status_code, 404)


if __name__ == '__main__':
    unittest.main()
