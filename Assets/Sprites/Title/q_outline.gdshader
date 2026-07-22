shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0, 0.85, 0.15, 1.0);
uniform float thickness : hint_range(0.0, 10.0) = 2.5;   // 边缘描边厚度（纹理像素）
uniform float glow : hint_range(0.0, 20.0) = 5.0;        // 外发光半径（纹理像素）
uniform float intensity : hint_range(0.0, 1.0) = 0.0;    // 悬停程度：0=无，1=满

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 size = vec2(textureSize(TEXTURE, 0));
	vec2 tx = thickness / size;
	vec2 gx = glow / size;

	// 紧贴字形边缘一圈
	float ring = 0.0;
	ring = max(ring, texture(TEXTURE, UV + vec2(tx.x, 0.0)).a);
	ring = max(ring, texture(TEXTURE, UV - vec2(tx.x, 0.0)).a);
	ring = max(ring, texture(TEXTURE, UV + vec2(0.0, tx.y)).a);
	ring = max(ring, texture(TEXTURE, UV - vec2(0.0, tx.y)).a);

	// 外围柔光
	float g = 0.0;
	g = max(g, texture(TEXTURE, UV + vec2(gx.x, 0.0)).a);
	g = max(g, texture(TEXTURE, UV - vec2(gx.x, 0.0)).a);
	g = max(g, texture(TEXTURE, UV + vec2(0.0, gx.y)).a);
	g = max(g, texture(TEXTURE, UV - vec2(0.0, gx.y)).a);
	g = max(g, texture(TEXTURE, UV + vec2(gx.x, gx.y)).a);
	g = max(g, texture(TEXTURE, UV - vec2(gx.x, gx.y)).a);
	g = max(g, texture(TEXTURE, UV + vec2(-gx.x, gx.y)).a);
	g = max(g, texture(TEXTURE, UV + vec2(gx.x, -gx.y)).a);

	float ring_mask = ring * (1.0 - base.a);   // 仅字形外侧
	float glow_mask = g * (1.0 - base.a);
	float add = clamp(glow_mask * 0.45 + ring_mask, 0.0, 1.0) * intensity;

	vec4 col = base;
	col.rgb = mix(col.rgb, outline_color.rgb, add);
	col.a = max(base.a, add * outline_color.a);
	COLOR = col;
}
