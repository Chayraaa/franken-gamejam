shader_type canvas_item;

uniform vec4 color : source_color = vec4(1.0);
uniform float width : hint_range(0, 10) = 1.0;
uniform int pattern : hint_range(0, 2) = 0; // diamond, circle, square
uniform bool inside = false;
uniform bool add_margins = true; // only useful when inside is false
uniform vec2 number_of_images = vec2(1.0); // number of horizontal and vertical images in the sprite sheet

varying flat vec4 modulate;

void vertex() {
	modulate = COLOR;
	
	if (add_margins) {
		if ((UV.x <= 0.0 || UV.x >= 1.0) && (UV.y <= 0.0 || UV.y >= 1.0)) {
			VERTEX += (UV * 2.0 - 1.0) * width;
		} else {
			VERTEX += sign(VERTEX) * width; // replace sign(VERTEX) by (sign(VERTEX) * 2.0 - 1.0) if your AnimatedSprite2D isn't Centered
		}
	}
}

void fragment() {
	vec2 uv = UV;
	vec2 image_top_left = floor(uv * number_of_images) / number_of_images;
	vec2 image_bottom_right = image_top_left + vec2(1.0) / number_of_images;
	
	if (add_margins) {
		vec2 texture_pixel_size = vec2(1.0) / (vec2(1.0) / TEXTURE_PIXEL_SIZE + vec2(width * 2.0) * number_of_images);
		
		uv = (uv - texture_pixel_size * width - image_top_left) * TEXTURE_PIXEL_SIZE / texture_pixel_size + image_top_left;
		
		if (uv != clamp(uv, image_top_left, image_bottom_right)) {
			COLOR.a = 0.0;
		} else {
			COLOR = texture(TEXTURE, uv) * modulate;
		}
	} else {
		COLOR = texture(TEXTURE, uv) * modulate;
	}
	
	// Sample TEXTURE directly; passing the built-in sampler to a helper
	// triggers a shader compiler error in the Compatibility renderer.
	bool contrary_neighbour = false;
	for (float i = -ceil(width); i <= ceil(width); i++) {
		float x = clamp(i, -width, width);
		float extent = width - abs(x);
		if (pattern == 1) {
			extent = floor(sqrt(max(0.0, pow(width + 0.5, 2.0) - x * x)));
		} else if (pattern == 2) {
			extent = width;
		}
		for (float j = -ceil(extent); j <= ceil(extent); j++) {
			vec2 neighbour = uv + TEXTURE_PIXEL_SIZE * vec2(x, clamp(j, -extent, extent));
			bool outside = neighbour != clamp(neighbour, image_top_left, image_bottom_right);
			if ((outside || texture(TEXTURE, neighbour).a <= 0.0) == inside) {
				contrary_neighbour = true;
			}
		}
	}
	if ((COLOR.a > 0.0) == inside && contrary_neighbour) {
		COLOR.rgb = inside ? mix(COLOR.rgb, color.rgb * modulate.rgb, color.a * modulate.a) : color.rgb * modulate.rgb;
		COLOR.a += (1.0 - COLOR.a) * color.a * modulate.a;
	}
}