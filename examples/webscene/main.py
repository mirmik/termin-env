#!/usr/bin/env python3
"""
Minimal example: termin scene → three.js web visualization.

Builds a simple 3D scene using termin meshes, then serves it
as a web page via FastAPI + three.js.

Usage:
    python main.py
    # Open http://localhost:8000 in browser
"""

import json
import numpy as np
from pathlib import Path
from http.server import HTTPServer, SimpleHTTPRequestHandler

from termin.mesh.primitives import (
    CubeMesh,
    UVSphereMesh,
    CylinderMesh,
    TorusMesh,
    ConeMesh,
)
from tgfx import Mesh3


STATIC_DIR = Path(__file__).parent / "static"
HOST = "0.0.0.0"
PORT = 8000


def build_scene() -> list[dict]:
    """Build scene as a list of mesh objects with transforms and colors."""
    objects = []

    # Ground plane (flat cube)
    objects.append({
        "name": "ground",
        "mesh": CubeMesh(size=6.0, y=0.1, z=6.0),
        "position": [0, -0.55, 0],
        "rotation": [0, 0, 0, 1],
        "scale": [1, 1, 1],
        "color": [0.35, 0.55, 0.35],
    })

    # Blue cube
    objects.append({
        "name": "cube",
        "mesh": CubeMesh(size=1.0),
        "position": [-1.5, 0.0, 0.0],
        "rotation": [0, 0, 0, 1],
        "scale": [1, 1, 1],
        "color": [0.3, 0.5, 0.8],
    })

    # Red sphere
    objects.append({
        "name": "sphere",
        "mesh": UVSphereMesh(radius=0.6, n_meridians=24, n_parallels=16),
        "position": [0.0, 0.1, 0.0],
        "rotation": [0, 0, 0, 1],
        "scale": [1, 1, 1],
        "color": [0.8, 0.25, 0.25],
    })

    # Yellow cylinder
    objects.append({
        "name": "cylinder",
        "mesh": CylinderMesh(radius=0.4, height=1.2, segments=24),
        "position": [1.5, 0.0, 0.0],
        "rotation": [0, 0, 0, 1],
        "scale": [1, 1, 1],
        "color": [0.85, 0.75, 0.2],
    })

    # Purple torus
    objects.append({
        "name": "torus",
        "mesh": TorusMesh(major_radius=0.5, minor_radius=0.15,
                          major_segments=24, minor_segments=12),
        "position": [0.0, 0.6, -1.5],
        "rotation": [0, 0, 0, 1],
        "scale": [1, 1, 1],
        "color": [0.6, 0.3, 0.7],
    })

    # Orange cone
    objects.append({
        "name": "cone",
        "mesh": ConeMesh(radius=0.5, height=1.0, segments=24),
        "position": [-1.5, 0.0, -1.5],
        "rotation": [0, 0, 0, 1],
        "scale": [1, 1, 1],
        "color": [0.9, 0.5, 0.15],
    })

    return objects


def mesh3_to_json(mesh: Mesh3) -> dict:
    """Convert Mesh3 to JSON-serializable dict for three.js."""
    data = {
        "vertices": mesh.vertices.flatten().tolist(),
        "indices": mesh.triangles.flatten().tolist(),
    }
    if mesh.has_normals:
        data["normals"] = mesh.vertex_normals.flatten().tolist()
    return data


def scene_to_json(objects: list[dict]) -> str:
    """Serialize scene objects to JSON string."""
    scene_data = []
    for obj in objects:
        scene_data.append({
            "name": obj["name"],
            "mesh": mesh3_to_json(obj["mesh"]),
            "position": obj["position"],
            "rotation": obj["rotation"],
            "scale": obj["scale"],
            "color": obj["color"],
        })
    return json.dumps(scene_data)


class SceneHandler(SimpleHTTPRequestHandler):
    """HTTP handler: serves static files and /api/scene endpoint."""

    scene_json: str = "[]"

    def do_GET(self):
        if self.path == "/":
            self.send_response(200)
            self.send_header("Content-Type", "text/html")
            self.end_headers()
            self.wfile.write((STATIC_DIR / "index.html").read_bytes())
        elif self.path == "/api/scene":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(self.scene_json.encode())
        else:
            # Serve static files
            file_path = STATIC_DIR / self.path.lstrip("/")
            if file_path.is_file():
                self.send_response(200)
                suffix = file_path.suffix
                content_types = {
                    ".js": "application/javascript",
                    ".css": "text/css",
                    ".html": "text/html",
                    ".json": "application/json",
                }
                self.send_header("Content-Type",
                                 content_types.get(suffix, "application/octet-stream"))
                self.end_headers()
                self.wfile.write(file_path.read_bytes())
            else:
                self.send_error(404)

    def log_message(self, format, *args):
        # Quiet logging
        pass


def main():
    print("Building termin scene...")
    objects = build_scene()
    scene_json = scene_to_json(objects)
    print(f"  {len(objects)} objects, {len(scene_json)} bytes JSON")

    SceneHandler.scene_json = scene_json

    server = HTTPServer((HOST, PORT), SceneHandler)
    print(f"Serving at http://localhost:{PORT}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")
        server.server_close()


if __name__ == "__main__":
    main()
