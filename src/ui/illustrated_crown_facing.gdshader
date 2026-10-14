shader_type canvas_item;
// Keep the original head geometry. Only its asymmetric mark changes brow when
// the body is reflected; preserve silhouette alpha and all actor tinting.
uniform vec4 source_mark;
uniform vec4 target_mark;
uniform vec2 skin_sample;
varying vec4 actor_tint;

void vertex() {
	actor_tint = COLOR;
}

bool inside_rect(vec2 point, vec4 rect) {
	return all(greaterThanEqual(point, rect.xy)) && all(lessThan(point, rect.xy + rect.zw));
}

bool crown_pixel(vec4 pixel) {
	return pixel.g > pixel.r * 0.8 && pixel.g > pixel.b * 1.03 && pixel.g > 0.25 && pixel.a > 0.5;
}

void fragment() {
	vec2 point = UV / TEXTURE_PIXEL_SIZE;
	vec4 pixel = texture(TEXTURE, UV);
	if (inside_rect(point, source_mark) && crown_pixel(pixel)) {
		pixel.rgb = texture(TEXTURE, skin_sample * TEXTURE_PIXEL_SIZE).rgb;
	}
	if (inside_rect(point, target_mark)) {
		vec2 mark_uv = (source_mark.xy + point - target_mark.xy) * TEXTURE_PIXEL_SIZE;
		vec4 mark = texture(TEXTURE, mark_uv);
		if (crown_pixel(mark)) {
			pixel.rgb = mark.rgb;
		}
	}
	COLOR = pixel * actor_tint;
}
