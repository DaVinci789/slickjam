shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest_mipmap;

// Texture properties
uniform ivec2 tex_size = ivec2(320, 180);
uniform vec2 tex_offset = vec2(0.0, 0.0);
uniform int blend_mode = 1;
uniform float opacity = 1.0;

// Palette properties
uniform bool palette_enabled = false;
uniform sampler2D palette_texture;
uniform float palette_index = 0.0;

// Axis distortion properties
uniform ivec2 axis_mode = ivec2(0, 0);
uniform ivec2 axis_frequency = ivec2(10, 10);
uniform ivec2 axis_amplitude = ivec2(5, 5);
uniform vec2 axis_shift = vec2(0.0, 0.0);

// Animation properties
uniform bool auto_animate = true;
uniform vec2 animation_speed = vec2(10.0, 5.0);

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
    // Animate axis shift
    vec2 current_shift = axis_shift;
    if (auto_animate) {
        current_shift += TIME * animation_speed;
    }

    // Convert UV to pixel coordinates
    ivec2 pixel_coords = ivec2(UV * vec2(tex_size));

    // Axis distortion
    ivec2 distortion = ivec2(
        distort(axis_mode.x,
                ivec2(pixel_coords.x, pixel_coords.y),
                axis_frequency.x,
                axis_amplitude.x,
                current_shift.x),
        distort(axis_mode.y,
                ivec2(pixel_coords.y, pixel_coords.x),
                axis_frequency.y,
                axis_amplitude.y,
                current_shift.y)
    );

    // Apply distortion
    vec2 distorted_uv =
        UV + tex_offset + vec2(distortion) / vec2(tex_size);

    // Sample source texture
    vec4 base_color = texture(TEXTURE, distorted_uv);

    // Palette lookup
    if (palette_enabled) {
        base_color = texture(
            palette_texture,
            vec2(base_color.r, palette_index)
        );
    }

    // Background (previous layers)
    vec3 bg = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;
    vec3 src = base_color.rgb;

    vec3 blended = src;

    // Blend modes
    if (blend_mode == 1) { // normal (alpha)
        blended = src;
        COLOR.rgb = mix(bg, blended, opacity);
    }
    else if (blend_mode == 2) { // add
        blended = bg + src;
        COLOR.rgb = mix(bg, blended, opacity);
    }
    else if (blend_mode == 3) { // subtract
        blended = bg - src;
        COLOR.rgb = mix(bg, blended, opacity);
    }
    else if (blend_mode == 4) { // screen (LOVE2D-style)
        // LÖVE's screen blend: lerp from bg*(1-fg) at opacity=0 to 1-(1-bg)*(1-fg) at opacity=1
        vec3 dark_blend = bg.rgb * (vec3(1.0) - base_color.rgb);
        vec3 screen_result = vec3(1.0) - (vec3(1.0) - bg.rgb) * (vec3(1.0) - base_color.rgb);
        COLOR.rgb = mix(dark_blend, screen_result, opacity);
        COLOR.a = 1.0;
    }
    else {
        COLOR.rgb = mix(bg, src, opacity);
    }

    COLOR.a = 1.0;
}
