shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.45, 1.0, 0.6, 1.0);
varying vec4 modulation;
void vertex() {
	modulation = COLOR;
}
void fragment() {
	vec4 ink = texture(TEXTURE, UV);
	float light = max(ink.r, max(ink.g, ink.b));
	vec3 hue = mix(tint.rgb, vec3(1.0), pow(light, 4.0) * 0.65);
	COLOR = vec4(hue * light, ink.a * tint.a) * modulation;
}
