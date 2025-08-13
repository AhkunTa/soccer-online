shader_type canvas_item;

uniform sampler2D team_palette;
uniform sampler2D team_skin_palette;

uniform int team_color;
uniform int skin_color;

vec2 px_to_uv(ivec2 pos, ivec2 tex_size) {
	return vec2(
		(float(pos[0]) + 0.5) / float(tex_size[0]),
		(float(pos[1]) + 0.5) / float(tex_size[1])
	);
}

vec4 get_pelette_color(vec4 color, sampler2D palette, int selection) {
	ivec2 tex_size = textureSize(palette, 0);
	for (int i=0; i<tex_size[0]; i++){
		vec2 uv_color_ref = px_to_uv(ivec2(i,0),tex_size);
		vec4 color_ref = texture(palette, uv_color_ref);
		if(color == color_ref) {
			vec2 uv_color_dest = px_to_uv(ivec2(i,selection),tex_size);
			return texture(palette, uv_color_dest);
		}
	}
	return color;
}



void fragment() {
	COLOR = get_pelette_color(COLOR, team_palette, team_color);
}
