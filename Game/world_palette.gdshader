shader_type canvas_item;

void fragment() {
	vec4 source = COLOR;
	float value = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	source.rgb = mix(vec3(value), source.rgb, 0.48) * vec3(0.96, 0.98, 0.92);
	COLOR = source;
}
