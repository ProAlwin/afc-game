# AFC Chicken Shop icons

- `afc_icon_512.png` is the square 512 × 512 game icon and Play Store listing artwork.
- `afc_adaptive_foreground_432.png` is the transparent Android adaptive-icon foreground. The chicken stays inside Android's centered 66% safe area so launcher masks do not crop it.
- `afc_adaptive_background_432.png` is the adaptive-icon background layer.
- `afc_adaptive_monochrome_432.png` is the optional Android 13+ themed-icon layer.
- The matching SVG files are the editable source artwork. Run `godot --headless --path . --script res://tools/generate_icons.gd` after editing them to regenerate the PNGs.

The Android APK and Google Play AAB presets already point at these icon files and declare support for small, normal, large, and extra-large Android screens. The Play preset targets API 36. Before publishing, set a unique final application ID and add your own release signing key in Godot's Android export settings.
