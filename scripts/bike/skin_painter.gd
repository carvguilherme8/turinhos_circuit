extends RefCounted
## Repinta a textura da moto ou do piloto com outras cores e outro número, usando os mapas
## gerados por tools/gen_skin_maps.py: cor = base + principal × R + detalhe × G; nos pixels
## do dígito escolhido, cor = cor do número × B.

## Mesmo valor de SCALE em tools/gen_skin_maps.py.
const SCALE := 1.5

const RIDER_DIR := "res://assets/models/riders/rider/rider"
const BIKE_DIR := "res://assets/models/bikes/motocross/motocross"
## Cor do número: branco nas costas do piloto, preto (cor do banco) nas placas da moto.
const RIDER_NUMBER_COLOR := Color8(242, 242, 236)
const BIKE_NUMBER_COLOR := Color8(34, 34, 40)


static func rider_texture(suit: Color, accent: Color, number: int) -> ImageTexture:
	return paint(RIDER_DIR, suit, accent, number, RIDER_NUMBER_COLOR)


static func bike_texture(plastic: Color, number: int) -> ImageTexture:
	return paint(BIKE_DIR, plastic, Color.BLACK, number, BIKE_NUMBER_COLOR)


static func paint(prefix: String, primary: Color, accent: Color, number: int, number_color: Color) -> ImageTexture:
	var base := _image(prefix + "_skin_base.png")
	var skin_map := _image(prefix + "_skin_map.png")
	var digits := _image(prefix + "_skin_digits.png")
	var out := Image.create(base.get_width(), base.get_height(), false, Image.FORMAT_RGBA8)
	var bit := 1 << clampi(number, 0, 9)
	for y in base.get_height():
		for x in base.get_width():
			var m := skin_map.get_pixel(x, y)
			var d := digits.get_pixel(x, y)
			var bits := d.r8 | (d.g8 << 8)
			var color: Color
			if bits & bit:
				color = number_color * (m.b * SCALE)
			else:
				color = base.get_pixel(x, y) + primary * (m.r * SCALE) + accent * (m.g * SCALE)
			color.a = 1.0
			out.set_pixel(x, y, color.clamp())
	return ImageTexture.create_from_image(out)


static func _image(path: String) -> Image:
	var image := (load(path) as Texture2D).get_image()
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	return image
