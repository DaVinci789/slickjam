shader_type canvas_item;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;
uniform ivec2 tex_size = ivec2(320, 180);
uniform int planar_mode = 0;
uniform float planar_amplitude = 0.0;

// Rendering control
uniform bool use_screen = false;
uniform bool use_pixelation = true; // Snap to pixel grid for hard edges (default)
uniform bool use_smooth_sampling = false; // Alternative: smooth filtering

// Animation properties
uniform bool auto_animate = false;
uniform float animation_speed = 0.5; // Speed of amplitude pulsing
uniform float animation_min = 0.3; // Minimum amplitude when pulsing
uniform float animation_max = 0.7; // Maximum amplitude when pulsing


vec2 distort(int d_mode, vec2 f_position, float i_amplitude) {
    vec2 offset_pos = f_position;
    
    if (d_mode == 0) { // fishbowl
        vec2 p = f_position;
        
        float prop = 1.0; // screen proportion
        
        vec2 m = vec2(0.5, 0.5); // center coords
        
        vec2 d = p - m; // vector from center to current fragment
        
        float r = sqrt(dot(d, d)); // distance of pixel from center
        
        float power = (2.0 * PI / (2.0 * sqrt(dot(m, m)))) * i_amplitude; // amount of effect
        
        float bind; // radius of 1:1 effect
        
        if (power > 0.0) {
            bind = sqrt(dot(m, m)); // stick to corners
        } else {
            if (prop < 1.0) {
                bind = m.x;
            } else {
                bind = m.y; // stick to borders
            }
        }
        
        // Weird formulas
        if (power > 0.0) { // fisheye
            offset_pos = m + normalize(d) * tan(r * power) * bind / tan(bind * power);
        } else if (power < 0.0) { // antifisheye
            offset_pos = m + normalize(d) * atan(r * -power * 10.0) * bind / atan(-power * bind * 10.0);
        } else {
            offset_pos = p; // no effect for power = 1.0
        }
    }
    
    if (d_mode == 1) { // placeholder mode
        offset_pos = vec2(tex_size);
    }
    
    return offset_pos;
}

void fragment() {
    // Calculate animated amplitude based on TIME
    float current_amplitude = planar_amplitude;
    if (auto_animate) {
        // Pulse between min and max using sine wave
        float pulse = (sin(TIME * animation_speed) + 1.0) * 0.5; // 0.0 to 1.0
        current_amplitude = mix(animation_min, animation_max, pulse);
    }
    
    vec2 distortion;
    if (use_screen) 
        distortion = distort(planar_mode, SCREEN_UV, current_amplitude);
    else
        distortion = distort(planar_mode, UV, current_amplitude);
    
    vec4 base_color;
    
    // Snap to pixel grid for hard pixel edges
    vec2 scale = vec2(tex_size);
    vec2 pixelated_uv = (floor(distortion * scale) + 0.5) / scale;
    if (use_screen)
        base_color = texture(SCREEN_TEXTURE, pixelated_uv);
    else
        base_color = texture(TEXTURE, pixelated_uv);
    
    COLOR = base_color;
    COLOR.a = 1.0;
}