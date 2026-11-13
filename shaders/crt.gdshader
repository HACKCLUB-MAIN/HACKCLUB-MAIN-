shader_type canvas_item;
// Retro CRT overlay applied to the TV's glass area.
// Plays a "power on" bright-band animation when the menu boots up
// (band_h grows from a thin line to the full screen, brightness rises with it),
// then settles into permanent scanlines, a rolling band, noise and a vignette.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float line_spacing = 3.2;   // px between scanlines (window pixels)
uniform float line_strength = 0.13;
uniform float roll_speed = 0.045;   // rolling band speed (uv/sec)
uniform float roll_height = 0.13;
uniform float roll_strength = 0.06;
uniform float noise_strength = 0.03;
uniform float vignette = 0.40;
uniform float band_h = 0.0;         // power-on band half-height in uv
uniform float brightness = 1.0;     // overall brightness during power-on

float rnd(vec2 s) {
	return fract(sin(dot(s, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;

	// scanlines
	float ypx = SCREEN_UV.y / SCREEN_PIXEL_SIZE.y;
	float ln = fract(ypx / line_spacing);
	c *= 1.0 - line_strength * smoothstep(0.15, 0.9, ln);

	// slow rolling bright band
	float roll_y = fract(TIME * roll_speed) * 1.2 - 0.1;
	float rd = SCREEN_UV.y - roll_y;
	c *= 1.0 + roll_strength * (1.0 - smoothstep(0.0, roll_height, abs(rd)));

	// noise flicker
	float nz = rnd(vec2(floor(SCREEN_UV.x / SCREEN_PIXEL_SIZE.x * 0.25), floor(TIME * 24.0))) - 0.5;
	c += nz * noise_strength;

	// vignette
	vec2 dv = SCREEN_UV - vec2(0.5);
	c *= 1.0 - vignette * dot(dv, dv) * 1.4;

	// power-on bright band: inside the band the screen is bright white,
	// outside it the picture fades in with `brightness`. When the band is
	// collapsed (band_h ~ 0) the overlay is a pure CRT filter.
	float inside = 0.0;
	if (band_h > 0.0005) {
		inside = 1.0 - smoothstep(band_h * 0.55, band_h, abs(SCREEN_UV.y - 0.5));
	}
	vec3 lit = mix(c * max(brightness, 0.001), vec3(1.0, 0.99, 0.92), 0.85 * inside + vec3(0.15).g * 0.0);
	c = mix(c * brightness, lit, inside);

	COLOR = vec4(c, 1.0);
}
