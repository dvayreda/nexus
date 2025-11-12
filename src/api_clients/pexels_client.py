import os
import requests
from typing import List, Dict

class PexelsClient:
    def __init__(self):
        self.api_key = os.getenv('PEXELS_API_KEY')
        self.base_url = "https://api.pexels.com/v1"
    
    def search_images(self, query: str, per_page: int = 10) -> List[Dict]:
        """Search for images using Pexels API"""
        try:
            headers = {"Authorization": self.api_key}
            params = {"query": query, "per_page": per_page}
            response = requests.get(f"{self.base_url}/search", headers=headers, params=params)
            response.raise_for_status()
            data = response.json()
            return data.get('photos', [])
        except Exception as e:
            raise Exception(f"Pexels API error: {str(e)}")
    
    def download_image(self, url: str, filepath: str) -> None:
        """Download image from URL to filepath"""
        try:
            response = requests.get(url)
            response.raise_for_status()
            with open(filepath, 'wb') as f:
                f.write(response.content)
        except Exception as e:
            raise Exception(f"Image download error: {str(e)}")