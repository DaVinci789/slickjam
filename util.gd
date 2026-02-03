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
