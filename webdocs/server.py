#!/usr/bin/env python3
"""Simple HTTP server with SPA routing for docsify."""

import http.server
import socketserver
import os

PORT = 3000
DIRECTORY = os.path.dirname(os.path.abspath(__file__))

class SPAHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)
    
    def end_headers(self):
        self.send_header('Cache-Control', 'no-cache')
        super().end_headers()
    
    def do_GET(self):
        path = self.translate_path(self.path)
        
        # If path doesn't exist, serve index.html (SPA routing)
        if not os.path.exists(path) or os.path.isdir(path):
            # Remove trailing slash for clean URLs
            if self.path.endswith('/') and self.path != '/':
                self.path = self.path.rstrip('/')
            
            # Try with .md extension
            md_path = path + '.md'
            if os.path.exists(md_path):
                self.path = self.path + '.md'
                return super().do_GET()
            
            # Default: serve index.html for SPA routing
            self.path = '/index.html'
        
        return super().do_GET()

if __name__ == '__main__':
    with socketserver.TCPServer(("", PORT), SPAHandler) as httpd:
        print(f"Serving at http://localhost:{PORT}")
        httpd.serve_forever()
