shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.55;
uniform float softness : hint_range(0.1, 2.0) = 0.7;
uniform vec3 vignette_color = vec3(0.85, 0.0, 0.0);

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float dist = length(uv);
	float v = smoothstep(softness, 1.6, dist);
	COLOR = vec4(vignette_color, v * intensity);
}
