# Godot 4 - 3D Pivot Changer Plugin

A lightweight and powerful editor tool for Godot 4.x that allows you to easily reposition the Pivot Point of any `MeshInstance3D` or `Node3D` without breaking your scene hierarchy.

## 🌟 Features
- **15 Presets:** Centers, 4 Bottom Corners, and 4 Top Corners.
- **Custom Scene Coordinate (XYZ):** Set pivot accurately to any global scene position.
- **Full Undo/Redo (`Ctrl + Z` / `Ctrl + Y`) support.**
- **Safe Mesh Processing:** Uncompresses surface data safely to avoid mesh corruption.
- **Node3D Support:** Repositions parent pivot without shifting child node global positions.

## 🚀 Installation
1. Download or clone this repository.
2. Copy the `addons/pivot_fixer` folder into your Godot project's `res://addons/` directory.
3. Open Godot, go to **Project -> Project Settings -> Plugins**, and enable **3D Pivot Changer**.
