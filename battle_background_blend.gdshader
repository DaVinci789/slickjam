shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;
uniform int blend_mode = 1;
uniform float opacity = 1.0;

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	vec3 bg = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;
	vec3 blended = src.rgb;

	if (blend_mode == 1) { // normal (alpha)
		COLOR.rgb = mix(bg, blended, opacity * src.a);
	}
	else if (blend_mode == 2) { // add
		blended = bg + src.rgb;
		COLOR.rgb = mix(bg, blended, opacity * src.a);
	}
	else if (blend_mode == 3) { // subtract
		blended = bg - src.rgb;
		COLOR.rgb = mix(bg, blended, opacity * src.a);
	}
	else if (blend_mode == 4) { // screen
		vec3 dark_blend = bg * (vec3(1.0) - src.rgb);
		vec3 screen_result = vec3(1.0) - (vec3(1.0) - bg) * (vec3(1.0) - src.rgb);
		COLOR.rgb = mix(dark_blend, screen_result, opacity);
	}
	else {
		COLOR.rgb = mix(bg, src.rgb, opacity * src.a);
	}

	COLOR.a = 1.0;
}
