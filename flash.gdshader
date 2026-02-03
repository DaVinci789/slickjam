shader_type canvas_item;

uniform float hit_effect : hint_range(0,1) = 0.0;
uniform float shake_intensity = 10.0;
uniform float flash_speed = 30.0;
uniform vec4 flash_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);

uniform sampler2D flash_curve; // CurveTexture

float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898,78.233))) * 43758.5453);
}

void vertex() {
    if (hit_effect > 0.0) {
        float time = TIME * 30.0;
        vec2 random_offset = vec2(
            rand(vec2(time, 0.0)) * 2.0 - 1.0,
            rand(vec2(time, 10.0)) * 2.0 - 1.0
        );
        VERTEX += random_offset * shake_intensity * hit_effect;
    }
}

void fragment() {
    if (hit_effect > 0.0) {
        vec4 base_color = texture(TEXTURE, UV) * COLOR;
        
        float t = fract(TIME * flash_speed);
        float curve_value = texture(flash_curve, vec2(t, 0.5)).r;
        curve_value *= base_color.a * hit_effect;

        vec4 flashed = mix(base_color, flash_color * base_color.a, curve_value);
        flashed.a = base_color.a;

        COLOR = flashed;
    } else {
        COLOR = texture(TEXTURE, UV);
    }
}
