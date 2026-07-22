shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0, 0.85, 0.15, 1.0);
uniform float thickness : hint_range(0.0, 10.0) = 2.5;   // 边缘描边厚度（纹理像素）
uniform float glow : hint_range(0.0, 20.0) = 5.0;        // 外发光半径（纹理像素）
uniform float intensity : hint_range(0.0, 1.0) = 0.0;    // 悬停程度：0=无，1=满
uniform float progress : hint_range(0.0, 1.0) = 1.0;     // 溶解显现进度：0=完全溶解隐藏，1=完全清晰
uniform float dissolve_edge : hint_range(0.0, 0.4) = 0.10; // 溶解前沿发光带宽度
uniform vec4 dissolve_color : source_color = vec4(1.0, 0.9, 0.55, 1.0); // 溶解前沿发光色

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	if (base.a < 0.01) { discard; }

	vec2 size = vec2(textureSize(TEXTURE, 0));
	vec2 tx = thickness / size;
	vec2 gx = glow / size;

	// ---- 溶解显现：从地面（UV.y=1 即底部）向上逐渐浮现 ----
	// 每像素噪声 + 垂直渐变，底部(field 高)优先显现
	float n = hash(floor(UV * 190.0));
	float field = n * 0.45 + UV.y * 0.55;          // 底部(UV.y=1) field 高 → 先显现
	float threshold = progress * (1.0 + dissolve_edge) - dissolve_edge;
	if (field > threshold) { discard; }            // 尚未到达此像素 → 仍溶解隐藏
	// 溶解前沿发光带：刚显现的像素最亮，早已显现的内部不发光
	float edge_band = smoothstep(threshold - dissolve_edge, threshold, field);

	// ---- 悬停描边/外发光（复用原 q_outline 逻辑）----
	float ring = 0.0;
	ring = max(ring, texture(TEXTURE, UV + vec2(tx.x, 0.0)).a);
	ring = max(ring, texture(TEXTURE, UV - vec2(tx.x, 0.0)).a);
	ring = max(ring, texture(TEXTURE, UV + vec2(0.0, tx.y)).a);
	ring = max(ring, texture(TEXTURE, UV - vec2(0.0, tx.y)).a);
	float g = 0.0;
	g = max(g, texture(TEXTURE, UV + vec2(gx.x, 0.0)).a);
	g = max(g, texture(TEXTURE, UV - vec2(gx.x, 0.0)).a);
	g = max(g, texture(TEXTURE, UV + vec2(0.0, gx.y)).a);
	g = max(g, texture(TEXTURE, UV - vec2(0.0, gx.y)).a);
	g = max(g, texture(TEXTURE, UV + vec2(gx.x, gx.y)).a);
	g = max(g, texture(TEXTURE, UV - vec2(gx.x, gx.y)).a);
	g = max(g, texture(TEXTURE, UV + vec2(-gx.x, gx.y)).a);
	g = max(g, texture(TEXTURE, UV + vec2(gx.x, -gx.y)).a);
	float ring_mask = ring * (1.0 - base.a);
	float glow_mask = g * (1.0 - base.a);
	float add = clamp(glow_mask * 0.45 + ring_mask, 0.0, 1.0) * intensity;

	vec4 col = base;
	// 溶解前沿发光
	col.rgb = mix(col.rgb, dissolve_color.rgb, edge_band * 0.9);
	col.a = max(base.a, edge_band * dissolve_color.a);
	// 悬停描边/外发光
	col.rgb = mix(col.rgb, outline_color.rgb, add);
	col.a = max(col.a, add * outline_color.a);
	COLOR = col;
}
