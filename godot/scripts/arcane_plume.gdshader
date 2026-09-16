shader_type canvas_item;
render_mode unshaded, blend_add;

// Explicit simulation-derived age also freezes turbulence when the game is paused.
uniform float age = 0.0;
uniform float power = 1.0;
uniform vec4 ember : source_color = vec4(1.0, 0.35, 0.08, 1.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
               mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float turbulence(vec2 p) {
    return noise(p) * 0.57 + noise(p * 2.03 + 7.1) * 0.28 + noise(p * 4.07 + 19.3) * 0.15;
}
void fragment() {
    float tail = 1.0 - UV.y;
    vec2 flow = vec2(UV.x * 5.0, tail * 5.0 - age * 8.0);
    float grain = turbulence(flow);
    float curl = sin(tail * 16.0 - age * 9.0) * tail * 0.04 + (grain - 0.5) * 0.16;
    float width = 0.12 + sqrt(tail) * 0.25;
    float envelope = exp(-pow((UV.x - 0.5 + curl) / width, 2.0) * 3.0);
    float body = envelope * pow(1.0 - tail, 1.35) * smoothstep(0.13, 0.65, grain + (1.0 - tail) * 0.35);
    float hot = pow(envelope, 3.0) * (1.0 - tail);
    vec3 color = mix(ember.rgb, vec3(1.0, 0.72, 0.26), body);
    color = mix(color, vec3(1.0, 0.95, 0.68), hot * 0.9);
    COLOR = vec4(color, body * power * smoothstep(0.0, 0.06, UV.y));
}
