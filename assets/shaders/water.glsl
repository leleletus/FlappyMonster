// assets/shaders/water.glsl
// Distorsiona la textura de escena capturada en zonas de agua.
// NO dibuja líneas — solo deforma lo que hay detrás.

extern float time;
extern float strength;
extern float speed;

// Noise suave
float hash(vec2 p) {
    p = fract(p * vec2(127.1, 311.7));
    p += dot(p, p + 19.19);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(hash(i),           hash(i + vec2(1,0)), u.x),
        mix(hash(i + vec2(0,1)), hash(i + vec2(1,1)), u.x),
        u.y
    );
}

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    float t = time * speed;

    // Distorsión orgánica multicapa — deforma lo que hay DETRÁS del agua
    float wx = sin(tc.y * 12.0 + t * 1.0) * strength * 2.0
             + sin(tc.y * 27.0 + t * 1.7 + tc.x * 8.0) * strength * 0.8
             + noise(vec2(tc.x * 6.0, tc.y * 6.0 + t * 0.5)) * strength * 1.5 - strength * 0.75;

    float wy = cos(tc.x * 10.0 + t * 0.8) * strength * 1.2
             + cos(tc.x * 22.0 + t * 1.4 + tc.y * 6.0) * strength * 0.5
             + noise(vec2(tc.x * 5.0 + t * 0.3, tc.y * 7.0)) * strength * 0.8 - strength * 0.4;

    vec2 distort = vec2(wx, wy);

    // Chromatic aberration: R, G, B se separan ligeramente
    float ca = strength * 1.2;
    float r  = Texel(tex, tc + distort + vec2( ca, 0.0)).r;
    float g  = Texel(tex, tc + distort).g;
    float b  = Texel(tex, tc + distort + vec2(-ca, 0.0)).b;
    float a  = Texel(tex, tc + distort).a;

    return vec4(r, g, b, a) * color;
}
