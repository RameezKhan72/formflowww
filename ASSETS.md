# Asset sources and licences (PRD 4.2)

| Asset | Files | Source | Licence |
|---|---|---|---|
| A1 Realistic anatomical body map (front and back), muscle masks, tap ID map | `assets/anatomy3d/` | Rendered in Blender from the **Z-Anatomy** 3D atlas (muscular and skeletal systems) by Lluís Vinent Juanico / Z-Anatomy, https://github.com/LluisV/Z-Anatomy. Scripts: `tool/anatomy/prepare.py`, `render_map.py`, `package_assets.py` | **CC BY-SA 4.0**. The rendered images are adaptations and are shared under the same licence. Attribution is shown in the app (Settings, About) |
| A2 Mini muscle chips | generated at runtime from A1 | FormFlow | as A1 |
| A3 3D exercise demonstrations (20 looping animations, 24 frames each way) | `assets/exercise_anim/*.webp` | The Z-Anatomy figure rigged and posed with FormFlow's own keyframes (`assets/data/exercises.json`) by `tool/anatomy/pose_render.py`, rendered in Blender (Cycles) | **CC BY-SA 4.0** (adaptation of Z-Anatomy) |
| A4 Thumbnails | `assets/thumbs/*.webp` | Peak frame of A3 | **CC BY-SA 4.0** |
| A3b 2D demonstrator (Lite profile, Demo mode, tracking overlay) | `lib/widgets/mannequin.dart` | Original | Project licence |
| A5 Props (dumbbells, barbell, bench, bar, wall) | modelled in `pose_render.py` / drawn in `mannequin.dart` | Original | Project licence |
| A6 Empty-state illustration, camera diagram | `lib/widgets/common.dart`, `exercise_detail_screen.dart` | Original | Project licence |
| Icons | Material Icons | Google | Apache 2.0 |

No FitAI artwork, names or branding are used; the look (grey anatomical figure, worked muscles in red) is recreated from an openly licensed anatomy model.

**Rebuilding the media** (needs the Z-Anatomy FBX files and `pip install bpy`):

```bash
python3 -I tool/anatomy/prepare.py -- <Z-Anatomy>/Resources/Models/FBX body.blend 0.3
python3 -I tool/anatomy/render_map.py -- body.blend out/map 720 1440
python3 -I tool/anatomy/pose_render.py -- body.blend assets/data/exercises.json out/poses 400 24
python3 tool/anatomy/package_assets.py out/map out/poses assets/data/exercises.json assets
```
