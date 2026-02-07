class_name Util

class Cut:
    var head: String
    var tail: String

static func cut(input: String, pattern: String) -> Cut:
    var result := Cut.new()
    var split_result := input.split(pattern, true, 1)
    result.head = split_result[0]
    result.tail = split_result[1] if len(split_result) == 2 else ""
    return result

static func game_to_window(node: Node, pos_320x180: Vector2) -> Vector2:
    var pos_ratio := Vector2(pos_320x180.x / 320.0, pos_320x180.y / 180)
    var window_size := node.get_window().get_size_with_decorations()
    return Vector2(window_size.x * pos_ratio.x, window_size.y * pos_ratio.y)

static func clamp_rect(inner: Rect2, outer: Rect2) -> Rect2:
    var clamped_pos := Vector2(
        clamp(
            inner.position.x,
            outer.position.x,
            outer.position.x + outer.size.x - inner.size.x
        ),
        clamp(
            inner.position.y,
            outer.position.y,
            outer.position.y + outer.size.y - inner.size.y
        )
    )
    return Rect2(clamped_pos, inner.size)

static func name_from_enemy_enum(type: Entity.EnemyType) -> String:
    return Entity.EnemyType.keys()[type]

static func _permute_mask(length: int) -> int:
    var mask: int = length - 1
    mask = mask | (mask >> 1)
    mask = mask | (mask >> 2)
    mask = mask | (mask >> 4)
    mask = mask | (mask >> 8)
    mask = mask | (mask >> 16)
    return mask

static func _permute_hash(idx: int, mask: int, seed: int) -> int:
    const M32: int = 0xFFFFFFFF
    idx = idx ^ seed; idx = (idx * 0xe170893d) & M32
    idx = idx ^ (seed >> 16)
    idx = idx ^ ((idx & mask) >> 4)
    idx = idx ^ (seed >> 8); idx = (idx * 0x0929eb3f) & M32
    idx = idx ^ (seed >> 23)
    idx = idx ^ ((idx & mask) >> 1); idx = (idx * (1 | (seed >> 27))) & M32
    idx = (idx * 0x6935fa69) & M32
    idx = idx ^ ((idx & mask) >> 11); idx = (idx * 0x74dcb303) & M32
    idx = idx ^ ((idx & mask) >> 2); idx = (idx * 0x9e501cc3) & M32
    idx = idx ^ ((idx & mask) >> 2); idx = (idx * 0xc860a3df) & M32
    idx = idx & mask
    idx = idx ^ (idx >> 5)
    return idx

static func permute(idx: int, length: int, seed: int) -> int:
    var mask: int = _permute_mask(length)
    idx = _permute_hash(idx, mask, seed)
    while idx >= length:
        idx = _permute_hash(idx, mask, seed)
    return (idx + seed) % length

static func permute_random(idx: int, length: int) -> int:
    return permute(idx, length, randi())

static func _get_sprite_size(sprite: Node2D) -> Vector2:
    if sprite is Sprite2D:
        return sprite.get_rect().size
    elif sprite is AnimatedSprite2D:
        var tex: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
        return tex.get_size()
    return Vector2.ZERO

static func get_shrunk_polygon(polygon: Polygon2D, sprite: Node2D) -> Array[PackedVector2Array]:
    var half_size: Vector2 = _get_sprite_size(sprite) * sprite.global_scale.abs() * 0.5
    var global_points: PackedVector2Array = PackedVector2Array()
    for point: Vector2 in polygon.polygon:
        global_points.append(polygon.to_global(point))
    var shrunk: Array[PackedVector2Array] = Geometry2D.offset_polygon(global_points, -half_size.x)
    var result_polys: Array[PackedVector2Array] = []
    for poly: PackedVector2Array in shrunk:
        result_polys.append_array(Geometry2D.offset_polygon(poly, -half_size.y))
    return result_polys

static func get_random_global_point_in_polygon2d_reduced_by_sprite_rect(polygon: Polygon2D, sprite: Node2D) -> Vector2:
    var global_points: PackedVector2Array = PackedVector2Array()
    for point: Vector2 in polygon.polygon:
        global_points.append(polygon.to_global(point))
    var result_polys: Array[PackedVector2Array] = get_shrunk_polygon(polygon, sprite)
    if result_polys.is_empty():
        # Sprite can't fit; return polygon center as fallback
        var center := Vector2.ZERO
        for point: Vector2 in global_points:
            center += point
        return center / float(global_points.size())
    # Build weighted list of triangulated polygons for uniform sampling
    var triangles: Array[PackedVector2Array] = []
    var areas: Array[float] = []
    var total_area: float = 0.0
    for poly: PackedVector2Array in result_polys:
        var indices: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
        for i: int in range(0, indices.size(), 3):
            var a: Vector2 = poly[indices[i]]
            var b: Vector2 = poly[indices[i + 1]]
            var c: Vector2 = poly[indices[i + 2]]
            var tri: PackedVector2Array = PackedVector2Array([a, b, c])
            var area: float = absf((b - a).cross(c - a)) * 0.5
            triangles.append(tri)
            areas.append(area)
            total_area += area
    # Pick a triangle weighted by area, then a uniform point within it
    var r: float = randf() * total_area
    var cumulative: float = 0.0
    var chosen: PackedVector2Array = triangles[0]
    for i: int in range(triangles.size()):
        cumulative += areas[i]
        if cumulative >= r:
            chosen = triangles[i]
            break
    var u: float = randf()
    var v: float = randf()
    if u + v > 1.0:
        u = 1.0 - u
        v = 1.0 - v
    return chosen[0] + u * (chosen[1] - chosen[0]) + v * (chosen[2] - chosen[0])
