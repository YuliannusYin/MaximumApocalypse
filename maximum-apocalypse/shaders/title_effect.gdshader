# [新增] 2026-06-24: 标题着色器，实现破损纹理和阴影增强效果
shader_type canvas_item;

# 破损纹理强度
uniform float damage_intensity : hint_range(0.0, 1.0) = 0.3;
# 阴影强度
uniform float shadow_intensity : hint_range(0.0, 2.0) = 1.5;
# 闪烁效果强度
uniform float flicker_intensity : hint_range(0.0, 1.0) = 0.1;
# 基础颜色
uniform vec4 base_color : source_color = vec4(0.769, 0.647, 0.455, 1.0);
# 破损颜色
uniform vec4 damage_color : source_color = vec4(0.3, 0.2, 0.15, 1.0);

void fragment() {
    # 获取基础颜色
    vec4 color = base_color;

    # 破损纹理效果：随机添加暗色斑点
    float damage = sin(UV.x * 20.0 + TIME * 2.0) * sin(UV.y * 15.0 + TIME * 1.5);
    damage = clamp(damage * damage_intensity, 0.0, 1.0);
    color = mix(color, damage_color, damage * 0.5);

    # 阴影增强：添加多层阴影
    vec2 shadow_offset = vec2(3.0, 3.0) / TEXTURE_PIXEL_SIZE;
    vec4 shadow_color = vec4(0.1, 0.1, 0.1, shadow_intensity);
    color.rgb = mix(color.rgb, shadow_color.rgb, shadow_color.a * 0.3);

    # 闪烁效果：轻微的亮度变化
    float flicker = sin(TIME * 3.0) * flicker_intensity;
    color.rgb = color.rgb + vec3(flicker);

    # 边缘破损效果
    float edge_damage = 0.0;
    if (UV.x < 0.1 || UV.x > 0.9 || UV.y < 0.1 || UV.y > 0.9) {
        edge_damage = sin(TIME * 5.0) * 0.2;
        color = mix(color, damage_color, edge_damage);
    }

    COLOR = color;
}