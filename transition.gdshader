shader_type canvas_item;
uniform vec4 transition_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	// Called for every pixel the material is visible on.
    vec4 new_color = COLOR;
    if (new_color.r == 0.0) {
        new_color = transition_color;
    } else {
        new_color = vec4(0.0);
    }
    COLOR = new_color;
}
