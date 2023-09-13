import os
import unittest
import requests


class TestMapProxyTile(unittest.TestCase):
    def setUp(self):
        # Set up the base URLs for your MapProxy instances based on config_path
        self.config_path = os.environ.get('config_path', '')
        service_url = 'http://0.0.0.0:8080'
        self.base_url = service_url + "/tms/1.0.0/Demo/osm_grid/"

    def test_tile_exists(self):
        # Define the tile coordinates (zoom, x, y)
        zoom_level = 5
        x_coordinate = 34
        y_coordinate = 28

        # Test each base URL
        tile_url = f'{self.base_url}{zoom_level}/{x_coordinate}/{y_coordinate}.png'

        # Send a GET request to the tile URL
        response = requests.get(tile_url)

        # Check if the response status code is 200 (OK)
        self.assertEqual(response.status_code, 200)

    def test_nonexistent_tile(self):
        # Define coordinates for a non-existent tile
        zoom_level = 5
        x_coordinate = 9999
        y_coordinate = 9999

        # Construct the URL for the non-existent tile
        tile_url = f'{self.base_url}{zoom_level}/{x_coordinate}/{y_coordinate}.png'

        # Send a GET request to the tile URL
        response = requests.get(tile_url)

        # Check if the response status code is 404 (Not Found)
        self.assertEqual(response.status_code, 404)


if __name__ == '__main__':
    unittest.main()
