shader_type canvas_item;
void fragment() {
	float edge = pow(abs(UV.x - 0.5) * 2.0, 2.0);
	float shade = smoothstep(0.54, 0.89, UV.y) * 0.26 + edge * 0.14;
	COLOR = vec4(0.02, 0.03, 0.05, shade);
}
