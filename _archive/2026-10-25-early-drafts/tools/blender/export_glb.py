"""Экспорт объектов из Blender в .glb для Godot.

Запуск из Blender (Scripting → Open → Run) или через Claude (MCP):
    exec(open(r"<путь_к_репо>/tools/blender/export_glb.py").read())
    export_glb("longsword", r"<путь_к_репо>")

Экспортирует видимые объекты текущей сцены в
game/assets/models/<name>/<name>.glb
"""
import os

import bpy


def export_glb(name: str, repo_root: str, selected_only: bool = False) -> str:
    out_dir = os.path.join(repo_root, "game", "assets", "models", name)
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, f"{name}.glb")
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=selected_only,
        use_visible=True,
        export_apply=True,       # применить модификаторы
        export_yup=True,         # Godot использует Y вверх
        export_texcoords=True,
        export_normals=True,
        export_materials="EXPORT",
        export_morph=True,       # shape keys для состояний broken/fixed
        export_animations=True,
    )
    return path
