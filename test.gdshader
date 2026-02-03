shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;
uniform int a = 0;
uniform int b = 0;
uniform float time_mod = 1.0;
int distort(int d_mode, ivec2 f_position, int i_frequency, int i_amplitude, float i_shift) {
    int offset_pos = 0;

    if (d_mode == 0) { // oscillation
        offset_pos = int(float(i_amplitude) *
            sin(((1.0 / float(i_frequency)) * PI) *
            (float(f_position.y) + i_shift)));
    }
    else if (d_mode == 1) { // interlaced
        int s = (f_position.y % 2 == 0) ? -1 : 1;
        offset_pos = s * int(float(i_amplitude) *
            sin(((1.0 / float(i_frequency)) * PI) *
            (float(f_position.y) + i_shift)));
    }
    else if (d_mode == 2) { // compression
        offset_pos = int(float(i_amplitude) *
            sin(((1.0 / float(i_frequency)) * PI) *
            (float(f_position.x) + i_shift)));
    }
    else if (d_mode == 3) { // linear scaling
        offset_pos = int((float(f_position.x) + i_shift) *
            (float(i_amplitude) / float(i_frequency)));
    }

    return offset_pos;
}

void fragment() {
    // Convert UV to pixel coordinates
    ivec2 pixel_coords = ivec2(SCREEN_UV * vec2(320, 180));
    ivec2 distortion = ivec2(
        distort(0,
                ivec2(pixel_coords.x, pixel_coords.y),
                a,
                b,
                TIME * time_mod),
        distort(2,
                ivec2(pixel_coords.y, pixel_coords.x),
                0,
                0,
                0)
    );
    // Apply distortion
    vec2 distorted_uv =
        UV + vec2(distortion) / vec2(320, 180);

    // Sample source texture
    vec4 base_color = texture(SCREEN_TEXTURE, distorted_uv);
    COLOR = base_color;
}
