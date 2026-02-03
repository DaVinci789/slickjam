class_name WaterStream
extends Node2D

class Result:
    var position := Vector2.ZERO
    var segment := 0

# Water stream parameters
@export var droplet_count: int = 20
@export var start_x: float = 0.0  # X position at start of arc
@export var end_x: float = 300.0  # X position at end of arc
@export var start_height: float = 0.0  # Y position at start of arc
@export var end_height: float = -50.0  # Y position at end of arc
@export var arc_height: float = 150.0  # How high the arc goes above the baseline
@export var stream_speed: float = 2.0  # Animation speed
@export var droplet_spacing: float = 15.0  # Space between droplets
@export var min_scale: float = 0.2  # Smallest droplet (furthest away)
@export var max_scale: float = 1.0  # Largest droplet (closest)

# Segment control (values from 0.0 to 1.0 representing position along arc)
# These act as boundaries - water shows between consecutive boundaries
@export var segments: Array[float] = [0.0]

# Debug
@export var show_droplets: bool = true  # Toggle droplet visibility for debugging
@export var show_debug_arc: bool = false
@export var debug_arc_color: Color = Color.RED
@export var debug_arc_width: float = 2.0
@export var debug_arc_segments: int = 50
@export var show_segment_markers: bool = true

# Reference to the white circle texture
@export var droplet_texture: Texture2D

var droplets: Array[Sprite2D] = []
var time_offset: float = 0.0

func _ready() -> void:
    create_water_stream()

func get_end_position() -> Vector2:
    return Vector2(end_x, end_height)
    
func get_droplet_per_normalized_progress(progress_normalized: float) -> Result:
    var result := Result.new()
    
    # Clamp progress to valid range
    var progress: float = clamp(progress_normalized, 0.0, 1.0)
    
    # Calculate X position (interpolate from start_x to end_x)
    var x: float = lerp(start_x, end_x, progress)
    
    # Baseline that interpolates from start_height to end_height
    var baseline: float = lerp(start_height, end_height, progress)
    
    # Arc component (parabolic, peaks in the middle)
    var arc_offset := -arc_height * sin(progress * PI)
    
    # Combine baseline with arc
    var y := baseline + arc_offset
    
    result.position = Vector2(x, y)
    
    # Determine which segment this progress falls into
    if segments.size() == 0:
        result.segment = 0
        return result
    
    # Sort the boundaries
    var boundaries := segments.duplicate()
    boundaries.sort()
    
    # Add implicit 0.0 and 1.0 if not present
    if boundaries[0] > 0.0:
        boundaries.insert(0, 0.0)
    if boundaries[-1] < 1.0:
        boundaries.append(1.0)
    
    # Find which segment we're in
    for i in range(boundaries.size() - 1):
        if progress >= boundaries[i] and progress <= boundaries[i + 1]:
            result.segment = i
            break
    
    return result

func create_water_stream() -> void:
    # Clear existing droplets
    for droplet in droplets:
        droplet.queue_free()
    droplets.clear()
    
    # Create new droplets
    for i in range(droplet_count):
        var droplet := Sprite2D.new()
        droplet.texture = droplet_texture
        droplet.modulate = Color(1, 1, 1, 0.7)  # Slight transparency
        add_child(droplet)
        droplets.append(droplet)

# Helper function to check if a progress value is within any segment
func is_in_segment(progress: float) -> bool:
    if segments.size() == 0:
        return true  # No boundaries means show everything
    
    # Sort the boundaries
    var boundaries := segments.duplicate()
    boundaries.sort()
    
    # Add implicit 0.0 and 1.0 if not present
    if boundaries[0] > 0.0:
        boundaries.insert(0, 0.0)
    if boundaries[-1] < 1.0:
        boundaries.append(1.0)
    
    # Check which segment we're in (segments are between consecutive boundaries)
    # Even-indexed segments (0, 2, 4...) are visible
    for i in range(boundaries.size() - 1):
        if progress >= boundaries[i] and progress <= boundaries[i + 1]:
            return i % 2 == 0
    
    return false

func _process(delta: float) -> void:
    time_offset += delta * stream_speed
    
    for i in range(droplets.size()):
        var droplet := droplets[i]
        
        # Calculate position along the stream (0 to 1, where 0 is start, 1 is end)
        var progress := fmod((float(i) / droplet_count) + time_offset, 1.0)
        
        # Check if this droplet is in an active segment and if droplets are enabled
        var in_segment := is_in_segment(progress)
        droplet.visible = show_droplets and in_segment
        
        if not droplet.visible:
            continue
        
        # Calculate X position (interpolate from start_x to end_x)
        var x: float = lerp(start_x, end_x, progress)
        
        # Baseline that interpolates from start_height to end_height
        var baseline: float = lerp(start_height, end_height, progress)
        
        # Arc component (parabolic, peaks in the middle)
        var arc_offset := -arc_height * sin(progress * PI)
        
        # Combine baseline with arc
        var y := baseline + arc_offset
        
        droplet.position = Vector2(x, y)
        
        # Scale based on distance (further = smaller)
        # Use quadratic falloff for more dramatic perspective
        var scale_factor: float = lerp(max_scale, min_scale, progress * progress)
        droplet.scale = Vector2(scale_factor, scale_factor)
        
        # Optional: Fade out droplets as they get further away
        droplet.modulate.a = lerp(0.8, 0.3, progress)
    
    # Trigger redraw for debug visualization
    #if show_debug_arc:
    queue_redraw()

func _draw() -> void:
    if not show_debug_arc:
        return
    
    # Draw the full arc path
    var points: PackedVector2Array = []
    
    for i in range(debug_arc_segments + 1):
        var progress := float(i) / debug_arc_segments
        
        # Calculate X position (interpolate from start_x to end_x)
        var x: float = lerp(start_x, end_x, progress)
        
        # Baseline that interpolates from start_height to end_height
        var baseline: float = lerp(start_height, end_height, progress)
        
        # Arc component (parabolic, peaks in the middle)
        var arc_offset := -arc_height * sin(progress * PI)
        
        # Combine baseline with arc
        var y := baseline + arc_offset
        
        points.append(Vector2(x, y))
    
    # Draw the arc as a polyline with dimmed color for inactive segments
    for i in range(points.size() - 1):
        var progress := float(i) / debug_arc_segments
        var in_segment := is_in_segment(progress)
        
        var line_color := debug_arc_color if in_segment else Color(debug_arc_color.r, debug_arc_color.g, debug_arc_color.b, 0.2)
        draw_line(points[i], points[i + 1], line_color, debug_arc_width)
    
    # Draw baseline reference (optional - shows the linear interpolation)
    draw_line(Vector2(start_x, start_height), Vector2(end_x, end_height), 
        Color(debug_arc_color.r, debug_arc_color.g, debug_arc_color.b, 0.3), 1.0)
    
    # Draw start and end markers
    draw_circle(Vector2(start_x, start_height), 5, Color.GREEN)  # Start point
    draw_circle(Vector2(end_x, end_height), 5, Color.BLUE)  # End point
    
    # Draw segment boundary markers
    if show_segment_markers and segments.size() > 0:
        var boundaries := segments.duplicate()
        boundaries.sort()
        
        # Add implicit boundaries for visualization
        if boundaries[0] > 0.0:
            boundaries.insert(0, 0.0)
        if boundaries[-1] < 1.0:
            boundaries.append(1.0)
        
        for i in range(boundaries.size()):
            var seg_progress: float = clamp(boundaries[i], 0.0, 1.0)
            
            # Calculate position at this segment point
            var x: float = lerp(start_x, end_x, seg_progress)
            var baseline: float = lerp(start_height, end_height, seg_progress)
            var arc_offset: float = -arc_height * sin(seg_progress * PI)
            var y := baseline + arc_offset
            
            # Alternate colors for start/end markers
            var marker_color := Color.YELLOW if i % 2 == 0 else Color.ORANGE
            draw_circle(Vector2(x, y), 4, marker_color)
            
            # Draw label
            var label := "B%d" % i  # B for "boundary"
            draw_string(ThemeDB.fallback_font, Vector2(x + 8, y - 8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, marker_color)
