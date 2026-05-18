#version 150

uniform sampler2D spectroTex;   // width = time, height = freq, R32F [0,1]
uniform float scrollOffset;
uniform int   colormapId;

in vec2 vSphereUV;
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
    fragColor = vec4(col, 1.0);
}
