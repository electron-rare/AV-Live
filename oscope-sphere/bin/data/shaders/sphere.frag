#version 150

uniform sampler2D spectroTex;   // width = time, height = freq, R32F [0,1]
uniform float scrollOffset;
uniform int   colormapId;
uniform int   renderMode;       // 0 = skin, 1 = points

in vec2  vSphereUV;
in vec3  vViewPos;
in float vWave;
out vec4 fragColor;

// Polynomial colormap fits (public domain, Matt Zucker).
vec3 magma(float t) {
    const vec3 c0 = vec3(-0.002136485053939,-0.000749655052795,-0.005386127855323);
    const vec3 c1 = vec3( 0.251660540737164, 0.677523243683767, 2.494026599312351);
    const vec3 c2 = vec3( 8.353717279216625,-3.577719514958484, 0.314467903013257);
    const vec3 c3 = vec3(-27.66873308576866, 14.26473078096533,-13.64921318813922);
    const vec3 c4 = vec3( 52.17613981234068,-27.94360607168351, 12.94416944238394);
    const vec3 c5 = vec3(-50.76852536473588, 29.04658282127291, 4.234152993845980);
    const vec3 c6 = vec3( 18.65570506591883,-11.48977351997711,-5.601961508734096);
    return c0+t*(c1+t*(c2+t*(c3+t*(c4+t*(c5+t*c6)))));
}
vec3 viridis(float t) {
    const vec3 c0 = vec3( 0.277727327223418, 0.005407344544967, 0.334099805335306);
    const vec3 c1 = vec3( 0.105093043108577, 1.404613529898575, 1.384590162594685);
    const vec3 c2 = vec3(-0.330861828725556, 0.214847559468213, 0.095095163028237);
    const vec3 c3 = vec3(-4.634230498983486,-5.799100973351585,-19.33244095627987);
    const vec3 c4 = vec3( 6.228269936347081,14.17993336680509, 56.69055260068105);
    const vec3 c5 = vec3( 4.776384997670288,-13.74514537774601,-65.35303263337234);
    const vec3 c6 = vec3(-5.435455855934631, 4.645852612178535, 26.3124352495832);
    return c0+t*(c1+t*(c2+t*(c3+t*(c4+t*(c5+t*c6)))));
}

void main() {
    float u = fract(vSphereUV.x - scrollOffset);
    float mag = clamp(texture(spectroTex, vec2(u, vSphereUV.y)).r, 0.0, 1.0);
    vec3 col = (colormapId == 0) ? magma(mag) : viridis(mag);

    if (renderMode == 1) {
        // round point sprites + a touch of waveform sheen
        vec2 d = gl_PointCoord - vec2(0.5);
        if (dot(d, d) > 0.25) discard;
        col += 0.20 * abs(vWave);
        fragColor = vec4(col, 1.0);
        return;
    }

    if (renderMode == 2) {
        // wireframe: bright unlit colormap lines
        fragColor = vec4(col * 1.4 + vec3(0.06), 1.0);
        return;
    }

    // skin: light the displaced relief with a screen-space face normal
    vec3 N = normalize(cross(dFdx(vViewPos), dFdy(vViewPos)));
    vec3 V = normalize(-vViewPos);
    if (dot(N, V) < 0.0) N = -N;
    vec3  L    = normalize(vec3(0.45, 0.65, 0.75));
    float diff = max(dot(N, L), 0.0);
    float rim  = pow(1.0 - max(dot(N, V), 0.0), 2.5);

    vec3 lit = col * (0.35 + 0.85 * diff) + rim * vec3(0.35, 0.45, 0.65);
    fragColor = vec4(lit, 1.0);
}
