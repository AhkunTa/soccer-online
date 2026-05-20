shader_type canvas_item;

uniform vec4 puddle_color : source_color = vec4(0.18, 0.42, 0.64, 0.36);
uniform vec4 swamp_color : source_color = vec4(0.12, 0.22, 0.13, 0.42);
uniform sampler2D noise_texture;
uniform float puddle_threshold : hint_range(-1.0, 1.0, 0.01) = 0.20;
uniform float swamp_threshold : hint_range(-1.0, 1.0, 0.01) = 0.35;
uniform float patch_threshold : hint_range(-1.0, 1.0, 0.01) = 0.20;
uniform vec4 patch_color : source_color = vec4(0.18, 0.42, 0.64, 0.36);
uniform bool use_single_patch_mask = false;
uniform float blur_radius : hint_range(0.0, 0.02, 0.0005) = 0.006;
uniform float edge_softness : hint_range(0.0, 0.2, 0.005) = 0.025;

float sample_noise(vec2 uv) {
	return texture(noise_texture, uv).r * 2.0 - 1.0;
}

float filtered_noise(vec2 uv) {
	if (blur_radius <= 0.0) {
		return sample_noise(uv);
	}

	float center = sample_noise(uv) * 4.0;
	float cardinals =
		sample_noise(uv + vec2(blur_radius, 0.0)) +
		sample_noise(uv + vec2(-blur_radius, 0.0)) +
		sample_noise(uv + vec2(0.0, blur_radius)) +
		sample_noise(uv + vec2(0.0, -blur_radius));
	float diagonals =
		sample_noise(uv + vec2(blur_radius, blur_radius)) +
		sample_noise(uv + vec2(-blur_radius, blur_radius)) +
		sample_noise(uv + vec2(blur_radius, -blur_radius)) +
		sample_noise(uv + vec2(-blur_radius, -blur_radius));
	return (center + cardinals * 2.0 + diagonals) / 16.0;
}

float threshold_mask(float value, float threshold) {
	if (edge_softness <= 0.0) {
		return step(threshold, value);
	}
	return smoothstep(threshold - edge_softness, threshold + edge_softness, value);
}

void fragment() {
	float value = filtered_noise(UV);

	if (use_single_patch_mask) {
		float patch = threshold_mask(value, patch_threshold);
		COLOR = patch_color * patch;
	} else {
		float puddle = threshold_mask(value, puddle_threshold);
		float swamp = threshold_mask(value, swamp_threshold);
		float puddle_only = max(puddle - swamp, 0.0);
		COLOR = puddle_color * puddle_only + swamp_color * swamp;
	}
}
