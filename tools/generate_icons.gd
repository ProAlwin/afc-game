extends SceneTree

func _initialize() -> void:
	var icon_dir := "res://assets/icons/"
	var files := {
		"afc_icon.svg": "afc_icon_512.png",
		"afc_adaptive_foreground.svg": "afc_adaptive_foreground_432.png",
		"afc_adaptive_background.svg": "afc_adaptive_background_432.png",
		"afc_adaptive_monochrome.svg": "afc_adaptive_monochrome_432.png"
	}
	for source_name in files:
		var source_file := FileAccess.open(icon_dir + source_name, FileAccess.READ)
		if source_file == null:
			push_error("Could not read %s" % source_name)
			quit(1)
			return
		var image := Image.new()
		var error := image.load_svg_from_string(source_file.get_as_text())
		if error != OK:
			push_error("Could not rasterize %s" % source_name)
			quit(1)
			return
		var output_name: String = files[source_name]
		var save_error := image.save_png(icon_dir + output_name)
		if save_error != OK:
			push_error("Could not save %s" % output_name)
			quit(1)
			return
		print("Created %s (%d x %d)" % [output_name, image.get_width(), image.get_height()])
	quit()
