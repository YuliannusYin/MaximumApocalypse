# [新增] 2026-06-24: 按钮着色器，实现悬停和点击效果
shader_type canvas_item;

# 悬停强度 (0.0-1.0)
uniform float hover_intensity : hint_range(0.0, 1.0) = 0.0;
# 点击强度 (0.0-1.0)
uniform float click_intensity : hint_range(0.0, 1.0) = 0.0;
# 基础颜色
uniform vec4 base_color : source_color = vec4(0.29, 0.23, 0.17, 1.0);
# 高亮颜色
uniform vec4 highlight_color : source_color = vec4(0.77, 0.65, 0.45, 1.0);

void fragment() {
    # 获取基础颜色
    vec4 color = base_color;

    # 悬停效果：增加亮度和饱和度
    if (hover_intensity > 0.0) {
        vec4 hover_color = mix(color, highlight_color, hover_intensity * 0.5);
        color = hover_color;

        # 添加发光效果
        float glow = hover_intensity * 0.3;
        COLOR.rgb = color.rgb + vec3(glow);
    } else {
        COLOR = color;
    }

    # 点击效果：闪烁和轻微缩小
    if (click_intensity > 0.0) {
        # 闪烁效果
        float flash = sin(TIME * 10.0) * 0.5 + 0.5;
        COLOR.rgb = mix(COLOR.rgb, highlight_color.rgb, click_intensity * flash * 0.3);
    }

    # 保持原始alpha
    COLOR.a = color.a;
}