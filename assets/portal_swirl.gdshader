shader_type canvas_item;

// Dimensional exit portal, drawn entirely in UV space (no sprite needed).
// A breathing bright rim around a dark core with rotating spiral arms and
// racing glints. Aspect-corrected so the oval never distorts.

uniform vec4 rim_color : source_color = vec4(0.45, 0.9, 1.0, 1.0);
uniform vec4 swirl_color : source_color = vec4(0.62, 0.36, 1.0, 1.0);
uniform vec4 core_color : source_color = vec4(0.07, 0.03, 0.15, 1.0);

void fragment() {
	// p-space: r = 1 sits exactly on the ellipse edge of the control's rect.
	vec2 p = (UV - vec2(0.5)) * vec2(1.53, 2.0);
	float r = length(p);
	float outer = smoothstep(1.0, 0.965, r);
	if (outer <= 0.0) {
		COLOR = vec4(0.0);
		return;
	}
	float ang = atan(p.y, p.x);

	// breathing rim: radius wobbles gently around the ring
	float rim_r = 0.92 + 0.018 * sin(TIME * 2.6 + ang * 3.0);
	float ring = smoothstep(rim_r, rim_r - 0.05, r)
		* smoothstep(rim_r - 0.2, rim_r - 0.12, r);

	// rotating spiral arms, quantized into bands for a pixel-art feel
	float spin = TIME * 1.5;
	float arms = 0.5 + 0.5 * sin(3.0 * ang + r * 14.0 - spin * 2.2);
	float band = floor(arms * 5.0) / 5.0;
	float radial = clamp(r / max(rim_r, 0.001), 0.0, 1.0);
	vec3 body = mix(core_color.rgb, swirl_color.rgb,
		band * (0.15 + 0.85 * radial * radial));

	// glints racing around just inside the rim
	float glint = step(0.94, sin(7.0 * ang - spin * 3.5)) * smoothstep(0.6, 0.88, r);
	body += rim_color.rgb * glint * 0.4;

	float inside = 1.0 - smoothstep(rim_r - 0.04, rim_r, r);
	vec3 col = mix(body, rim_color.rgb, clamp(ring, 0.0, 1.0));
	float alpha = clamp(max(inside, ring * 1.1), 0.0, 1.0) * outer;
	COLOR = vec4(col, alpha);
}
