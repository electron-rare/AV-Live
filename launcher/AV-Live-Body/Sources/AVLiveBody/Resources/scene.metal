// scene.metal — fond reactif aux flux data_feeds + skeleton overlay.
//
// 9 modes visuels style demoscene 2023+ (raymarching SDF, fractales,
// parallax, palette IQ). Reactivite open-data via SceneUniforms.
//   0 storm     fbm tissu palette Kp/Bz + lightning flash
//   1 tunnel    raymarched tube avec anneaux translucents (wind, RMS)
//   2 plasma    volumetric noise palette IQ (Kp, social_rate)
//   3 kaleido   fractal KIFS 6-fold rotation 3D (flare, time)
//   4 voronoi   cellular 3D crystal sphere (lightning, RMS)
//   5 metaballs raymarched SDF metaballs colored shading (RMS, beat)
//   6 starfield galaxy spiral parallax + god rays (wind, kp)
//   7 bars      3D pillars en perspective avec depth fog (RMS+social)
//   8 hands3d   raymarching mandelbox-like + hands camera control

#include <metal_stdlib>
using namespace metal;

struct SceneUniforms {
    float time;
    float rms;
    float kp_norm;
    float netz_dev;
    float lightning_flash;
    float flare;
    float wind_norm;
    float bz_norm;
    float social_rate;
    float pose_alive;
    float pose_count;
    float width;
    float height;
    float viz_mode;
    float hand_l_x;
    float hand_l_y;
    float hand_r_x;
    float hand_r_y;
    float _pad0;
    float _pad1;
};

struct VsOut {
    float4 position [[position]];
    float2 uv;
};

vertex VsOut bg_vertex(uint vid [[vertex_id]]) {
    float2 p = float2((vid << 1) & 2, vid & 2);
    VsOut o;
    o.position = float4(p * 2.0 - 1.0, 0.0, 1.0);
    o.uv = p;
    return o;
}

// ===== Helpers ====================================================

float hash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}
float hash31(float3 p) {
    p = fract(p * 0.1031);
    p += dot(p, p.yzx + 33.33);
    return fract((p.x + p.y) * p.z);
}
float noise2(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float a = hash21(i);
    float b = hash21(i + float2(1, 0));
    float c = hash21(i + float2(0, 1));
    float d = hash21(i + float2(1, 1));
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}
float fbm(float2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 5; ++i) { v += a * noise2(p); p *= 2.13; a *= 0.5; }
    return v;
}

// Palette cosinusoidale IQ : 3 tons doux
float3 palIQ(float t, float3 a, float3 b, float3 c, float3 d) {
    return a + b * cos(6.28318 * (c * t + d));
}

// Rotations
float3 rotY(float3 p, float a) {
    float c = cos(a), s = sin(a);
    return float3(c * p.x + s * p.z, p.y, -s * p.x + c * p.z);
}
float3 rotX(float3 p, float a) {
    float c = cos(a), s = sin(a);
    return float3(p.x, c * p.y - s * p.z, s * p.y + c * p.z);
}
float3 rotZ(float3 p, float a) {
    float c = cos(a), s = sin(a);
    return float3(c * p.x - s * p.y, s * p.x + c * p.y, p.z);
}

// SDF primitives
float sdSphere(float3 p, float r) { return length(p) - r; }
float sdBox(float3 p, float3 b) {
    float3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}
float sdTorus(float3 p, float2 t) {
    float2 q = float2(length(p.xz) - t.x, p.y);
    return length(q) - t.y;
}
float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

float vignette(float2 p) {
    return 1.0 - smoothstep(0.6, 1.5, length(p));
}

// ===== Modes =======================================================

// ---- 0 storm : tissu fbm reactif + bloom-fake ----
float3 mode_storm(float2 p, constant SceneUniforms& U) {
    float storm = saturate(U.kp_norm * 1.0 + max(-U.bz_norm, 0.0) * 0.5);
    float speed = 0.08 + U.wind_norm * 1.5;
    float zoom = 1.8 - U.rms * 1.2;
    float n = fbm(p * zoom + float2(U.time * speed, U.time * speed * 0.7));
    n = pow(n, 1.2 - U.rms * 0.5);
    float netz = sin(U.time * 50.0 + U.netz_dev * 800.0) * 0.06;
    float3 base = palIQ(n + storm * 0.5,
        float3(0.10, 0.05, 0.20),
        float3(0.40, 0.30, 0.55),
        float3(1.0,  1.0,  1.0),
        float3(0.0, 0.33, 0.67));
    float bloom = smoothstep(0.7, 1.0, n);
    return base * (n * 1.4 + 0.3) + netz + U.rms * 1.2
         + bloom * 0.7
         + float3(1.0, 0.55, 0.1) * U.flare * 1.4
         + float3(U.lightning_flash * 0.7);
}

// ---- 1 tunnel : raymarched cylindrical tube avec anneaux ----
float3 mode_tunnel(float2 p, constant SceneUniforms& U) {
    // Pseudo-3D tunnel: r/theta + scrolling z
    float r = length(p);
    float a = atan2(p.y, p.x);
    float z = U.time * (1.5 + U.wind_norm * 8.0 + U.rms * 4.0);
    // Repeat depth
    float d = 1.0 / max(r, 0.04) + z;
    // anneaux + spirale
    float ring = sin(d * 4.0) * 0.5 + 0.5;
    float spiral = sin(a * (8.0 + U.kp_norm * 6.0) + d * 0.6);
    float v = ring * (0.4 + 0.6 * spiral);
    // Iris central
    v *= smoothstep(0.05, 0.20, r);
    float3 base = palIQ(d * 0.06 + U.time * 0.05,
        float3(0.15, 0.05, 0.35),
        float3(0.55, 0.25, 0.35),
        float3(1.0,  1.0,  0.8),
        float3(0.0, 0.10, 0.20));
    float3 col = base * v;
    // Chromatic aberration fake : sample displaced
    float chrom = U.lightning_flash * 0.15;
    col.r *= 1.0 + chrom; col.b *= 1.0 - chrom;
    return col + float3(1.0, 0.7, 0.3) * U.flare * 1.5
              + float3(U.lightning_flash * 0.6);
}

// ---- 2 plasma : volumetric noise palette IQ ----
float3 mode_plasma(float2 p, constant SceneUniforms& U) {
    float t = U.time * (0.5 + U.rms * 1.5);
    // 3 octaves de sin/cos en composition
    float v = sin(p.x * 4.0 + t)
            + sin(p.y * 5.0 - t * 1.2)
            + sin((p.x + p.y) * 3.5 + t * 0.7)
            + sin(length(p) * (8.0 + U.kp_norm * 4.0) - t * 1.8);
    v = v * 0.25 + 0.5;
    // Fake volumetric "depth" : repeat layers
    float layer2 = sin(p.x * 2.0 - t * 0.5) * sin(p.y * 2.5 + t * 0.7);
    v = mix(v, v * 0.5 + 0.5 * (layer2 + 1.0) * 0.5, 0.35);
    float3 col = palIQ(v,
        float3(0.5),
        float3(0.5),
        float3(1.0, 1.0, 1.0),
        float3(0.0, 0.33, 0.67));
    col *= 0.8 + U.kp_norm * 0.7 + U.social_rate * 0.5;
    return col + float3(0.6, 0.3, 1.0) * U.lightning_flash * 0.5;
}

// ---- 3 kaleido : KIFS fractal 6-fold avec rot 3D fake ----
float3 mode_kaleido(float2 p, constant SceneUniforms& U) {
    float ang = U.time * 0.15 + U.flare * 2.0;
    float c = cos(ang), s = sin(ang);
    p = float2(c * p.x - s * p.y, s * p.x + c * p.y);
    float r = length(p);
    float a = atan2(p.y, p.x);
    float seg = 6.28318 / 6.0;
    a = abs(fmod(a + seg * 0.5, seg) - seg * 0.5);
    float2 q = float2(cos(a), sin(a)) * r;
    // Iteration KIFS-like
    float scale = 1.0;
    for (int i = 0; i < 4; ++i) {
        q = abs(q) - 0.35;
        if (q.y > q.x) q = q.yx;
        q *= 1.5; scale *= 1.5;
    }
    float v = length(q) / scale;
    float n = fbm(q * 3.0 + U.time * 0.2);
    float3 col = palIQ(v + n * 0.3,
        float3(0.20, 0.10, 0.30),
        float3(0.55, 0.40, 0.50),
        float3(1.0, 1.0, 0.5),
        float3(0.0, 0.25, 0.50));
    col = col * (1.0 - exp(-v * 6.0));
    return col * (0.8 + U.rms * 1.0)
         + float3(1.0, 0.6, 0.2) * U.flare * 1.2;
}

// ---- 4 voronoi : 3D crystalline cellular ----
float3 mode_voronoi(float2 p, constant SceneUniforms& U) {
    // 3D voronoi : on echantillonne dans une grille 3D animee
    float t = U.time * (0.4 + U.rms * 1.0);
    float3 P = float3(p * 3.5, t);
    float3 ip = floor(P);
    float3 fp = fract(P);
    float d1 = 10.0, d2 = 10.0;
    for (int z = -1; z <= 1; ++z)
    for (int y = -1; y <= 1; ++y)
    for (int x = -1; x <= 1; ++x) {
        float3 g = float3(float(x), float(y), float(z));
        float3 o = float3(hash31(ip + g + 13.0),
                          hash31(ip + g + 71.0),
                          hash31(ip + g + 47.0));
        o = 0.5 + 0.5 * sin(t + 6.28 * o);
        float3 dv = g + o - fp;
        float d = dot(dv, dv);
        if (d < d1) { d2 = d1; d1 = d; }
        else if (d < d2) { d2 = d; }
    }
    d1 = sqrt(d1); d2 = sqrt(d2);
    float edge = smoothstep(0.0, 0.04, d2 - d1);  // walls between cells
    float face = smoothstep(0.0, 0.6, d1);
    float3 base = palIQ(d1,
        float3(0.05, 0.08, 0.20),
        float3(0.45, 0.35, 0.55),
        float3(1.0, 1.0, 0.6),
        float3(0.2, 0.3, 0.0));
    return base * (1.0 - face) + float3(1.0) * (1.0 - edge) * 0.5
         + U.lightning_flash * 0.8;
}

// ---- 5 metaballs : raymarched SDF ----
float metaballs_dist(float3 p, constant SceneUniforms& U) {
    float t = U.time * 0.7;
    float d = 100.0;
    for (int k = 0; k < 5; ++k) {
        float fk = float(k);
        float3 c = float3(
            sin(t * (0.6 + 0.13 * fk) + fk * 1.7) * 1.2,
            cos(t * (0.5 + 0.11 * fk) + fk * 2.1) * 1.0,
            sin(t * (0.4 + 0.09 * fk) + fk * 3.0) * 0.8
        );
        float radius = 0.45 + 0.15 * U.rms + 0.05 * sin(t + fk);
        d = smin(d, sdSphere(p - c, radius), 0.45);
    }
    return d;
}
float3 mode_metaballs(float2 p, constant SceneUniforms& U) {
    float3 ro = float3(0, 0, -3.5);
    float3 rd = normalize(float3(p, 1.5));
    float t = 0.0;
    float glow = 0.0;
    int i;
    for (i = 0; i < 64; ++i) {
        float3 pos = ro + rd * t;
        float d = metaballs_dist(pos, U);
        if (d < 0.01) break;
        glow += 0.02 / (1.0 + d * d * 4.0);
        t += d * 0.9;
        if (t > 8.0) break;
    }
    float3 col = float3(0);
    if (t < 8.0) {
        float3 pos = ro + rd * t;
        // normal via gradient
        float2 e = float2(0.001, 0);
        float3 n = normalize(float3(
            metaballs_dist(pos + e.xyy, U) - metaballs_dist(pos - e.xyy, U),
            metaballs_dist(pos + e.yxy, U) - metaballs_dist(pos - e.yxy, U),
            metaballs_dist(pos + e.yyx, U) - metaballs_dist(pos - e.yyx, U)));
        float3 lightDir = normalize(float3(0.6, 0.8, -0.5));
        float lambert = max(0.0, dot(n, lightDir));
        float fres = pow(1.0 - max(0.0, dot(n, -rd)), 2.0);
        col = palIQ(pos.x * 0.3 + pos.y * 0.2 + U.time * 0.1,
            float3(0.2, 0.0, 0.3),
            float3(0.5, 0.5, 0.4),
            float3(1.0),
            float3(0.0, 0.33, 0.67)) * lambert;
        col += float3(0.3, 0.7, 1.0) * fres * (0.7 + U.kp_norm);
    }
    col += float3(0.2, 0.6, 1.0) * glow * 1.5;
    return col + U.lightning_flash * 0.6;
}

// ---- 6 starfield : galaxy spiral + parallax ----
float3 mode_starfield(float2 p, constant SceneUniforms& U) {
    float warp = U.time * (1.5 + U.wind_norm * 6.0);
    // 3 layers of stars at different speeds
    float3 col = float3(0);
    for (int L = 0; L < 3; ++L) {
        float speed = (1.0 + float(L) * 0.5);
        float scale = 6.0 + float(L) * 4.0;
        for (int k = 0; k < 50; ++k) {
            float fk = float(k + L * 50);
            float r0 = hash21(float2(fk, 7.0 + float(L)));
            float a0 = hash21(float2(fk, 17.0 + float(L))) * 6.28;
            // Spirale galactique
            float angle = a0 + r0 * 4.0;
            float dist = fract(r0 + warp * 0.04 * speed) * 1.6;
            float2 q = float2(cos(angle + dist * 1.5),
                              sin(angle + dist * 1.5)) * dist;
            float d = length(p - q);
            float bright = smoothstep(0.012 / speed, 0.0, d);
            col += float3(0.5 + r0 * 0.5, 0.7 - r0 * 0.3, 1.0) * bright
                 * (1.4 - dist) * (1.0 / speed);
        }
    }
    // God rays subtils depuis le centre
    float ang = atan2(p.y, p.x);
    float rays = 0.5 + 0.5 * sin(ang * 8.0 + U.time);
    col += float3(0.3, 0.4, 0.7) * rays * (1.0 - length(p)) * 0.15
         * (0.5 + U.kp_norm);
    return col + U.flare * float3(1.0, 0.5, 0.2) * 0.4;
}

// ---- 7 bars : 3D pillars en perspective ----
float3 mode_bars(float2 p, constant SceneUniforms& U) {
    // Pseudo-3D : barres "horizontales" qui s'eloignent
    int nbars = 24;
    float t = U.time * 0.4;
    float3 col = float3(0);
    // Sky gradient
    float3 sky = mix(float3(0.05, 0.0, 0.15), float3(0.25, 0.1, 0.35),
                     p.y * 0.5 + 0.5);
    col = sky;
    for (int i = 0; i < nbars; ++i) {
        float fi = float(i) / float(nbars);
        // Position en profondeur (z = 0 proche, 1 loin)
        float z = fract(fi + t * (0.15 + U.rms * 0.3));
        float perspective = 1.0 / (z + 0.1);
        float y_base = -0.6 + z * 1.2;   // ligne d'horizon
        // Hauteur barre depend du bin "i" via hash + RMS
        float h0 = hash21(float2(float(i), 0.0));
        float h = sin(t * (0.5 + h0 * 4.0) + float(i)) * 0.5 + 0.5;
        h = h * (0.3 + U.rms * 1.5 + U.social_rate * 0.4);
        h = clamp(h, 0.02, 0.85);
        float bar_top = y_base + h * perspective * 0.3;
        // Largeur = 1 / nbars perspective
        float bx = (fi - 0.5) * perspective * 1.5;
        float bw = 0.5 / float(nbars) * perspective;
        if (abs(p.x - bx) < bw &&
            p.y > y_base && p.y < bar_top) {
            float3 c = palIQ(fi,
                float3(0.5), float3(0.5),
                float3(1.0, 1.0, 0.5),
                float3(0.0, 0.33, 0.67));
            // Fog selon z
            c *= 1.0 - z * 0.6;
            col = mix(col, c, 1.0 - z * 0.3);
        }
    }
    // Grille du sol scanline
    float floor_y = -0.6;
    if (p.y < floor_y) {
        float depth = (floor_y - p.y) * 4.0;
        float grid = step(0.95, fract(p.x * 8.0 / max(depth, 0.1)));
        grid += step(0.95, fract(depth * 4.0 + t));
        col += float3(0.2, 0.3, 0.6) * grid * 0.4;
    }
    return col + U.flare * float3(1.0, 0.5, 0.2) * 0.3;
}

// ---- 8 hands3d : voyage 3D pilote par les mains ----
float map_hands(float3 p, constant SceneUniforms& U) {
    float3 q = fmod(p + 2.0, 4.0) - 2.0;
    float d = length(q) - 0.6;
    float pulse = 0.8 + U.rms * 0.6;
    d = min(d, length(p) - pulse);
    d += sin(p.x * 2.0 + U.time) * 0.15 * U.kp_norm;
    return d;
}
float3 mode_hands3d(float2 p, constant SceneUniforms& U) {
    float hl_active = (abs(U.hand_l_x) + abs(U.hand_l_y)) > 0.01 ? 1.0 : 0.0;
    float hr_active = (abs(U.hand_r_x) + abs(U.hand_r_y)) > 0.01 ? 1.0 : 0.0;
    float3 cam_pos = float3(
        U.hand_l_x * 5.0,
        U.hand_l_y * 3.0,
        -U.time * (1.5 + U.hand_l_y * 4.0 * hl_active)
    );
    float yaw   = U.hand_r_x * 1.2 * hr_active;
    float pitch = -U.hand_r_y * 0.8 * hr_active;
    float3 rd = normalize(float3(p.x, p.y, 1.5));
    rd = rotX(rd, pitch);
    rd = rotY(rd, yaw);
    float t = 0.0, glow = 0.0;
    for (int i = 0; i < 64; ++i) {
        float3 pos = cam_pos + rd * t;
        float d = map_hands(pos, U);
        if (d < 0.005) break;
        glow += 0.02 / (1.0 + d * d * 8.0);
        t += d * 0.85;
        if (t > 30.0) break;
    }
    float3 col = float3(0);
    if (t < 30.0) {
        float3 pos = cam_pos + rd * t;
        float fog = 1.0 - saturate(t / 30.0);
        col = float3(
            0.5 + 0.5 * sin(pos.x * 0.4 + U.time),
            0.5 + 0.5 * sin(pos.y * 0.5 + U.time * 1.3),
            0.5 + 0.5 * sin(pos.z * 0.3 + U.time * 0.7)
        ) * fog;
    }
    col += float3(0.2, 0.6, 1.0) * glow * 1.5;
    col += float3(1.0, 0.5, 0.0) * U.flare * 0.8;
    return col;
}

// ---- 9 openpos : fond minimal radial pour faire ressortir le squelette ----
// Le rendu des joints + bones se fait par le skel_pipeline rendu PAR-DESSUS
// (cf renderer.py). On laisse juste un degrade radial sombre pour le contraste.
float3 mode_openpos(float2 p, constant SceneUniforms& U) {
    float r = length(p);
    // Centre legerement plus clair, bords sombres. Touche de couleur
    // chaude au centre selon rms pour reagir a la musique.
    float3 inner = float3(0.05, 0.05, 0.10) + float3(0.30, 0.12, 0.18) * U.rms;
    float3 outer = float3(0.01, 0.01, 0.02);
    float3 col = mix(inner, outer, smoothstep(0.0, 1.4, r));
    // Grille de points discrete pour donner une ref de profondeur
    float2 g = fmod(p * 12.0, 2.0) - 1.0;
    float dot_grid = exp(-dot(g, g) * 6.0) * 0.04;
    col += float3(dot_grid);
    // Pulsation legere sur le kick / drop
    col *= 1.0 + U.rms * 0.4;
    return col;
}

// ===== Fragment dispatcher =========================================

fragment float4 bg_fragment(VsOut in [[stage_in]],
                            constant SceneUniforms& U [[buffer(0)]]) {
    float2 uv = in.uv;
    float2 p = uv * 2.0 - 1.0;
    p.x *= U.width / U.height;

    int mode = int(U.viz_mode + 0.5);
    float3 color;
    if      (mode == 1) color = mode_tunnel(p, U);
    else if (mode == 2) color = mode_plasma(p, U);
    else if (mode == 3) color = mode_kaleido(p, U);
    else if (mode == 4) color = mode_voronoi(p, U);
    else if (mode == 5) color = mode_metaballs(p, U);
    else if (mode == 6) color = mode_starfield(p, U);
    else if (mode == 7) color = mode_bars(p, U);
    else if (mode == 8) color = mode_hands3d(p, U);
    else if (mode == 9) color = mode_openpos(p, U);
    else                color = mode_storm(p, U);

    // Flash global + vignette
    color += float3(U.lightning_flash * 1.2);
    color *= vignette(p);

    // Tone mapping doux (Reinhard)
    color = color / (1.0 + color);
    // Gamma
    color = pow(color, float3(0.85));

    // Alpha pour transparence quand pose active (webcam visible dessous)
    // Overlay vidéo : translucide même sans pose (la webcam doit rester
    // visible en fond). Pose active = encore plus translucide.
    float alpha = mix(0.55, 0.25, U.pose_alive);
    alpha = max(alpha, U.lightning_flash * 0.8);
    alpha = max(alpha, U.flare * 0.6);
    return float4(color, alpha);
}

// ===== Skeleton overlay ============================================

struct SkelIn {
    float3 pos      [[attribute(0)]];   // x,y dans NDC, z profondeur (~ -0.5..+0.5)
    float  conf     [[attribute(1)]];
    float  pid      [[attribute(2)]];   // person_id (0..9)
};
struct SkelOut {
    float4 position [[position]];
    float  conf;
    float  pid;
    float  depth;
};

// Projection perspective douce : eloigne avec z, garde NDC en x,y
vertex SkelOut skel_vertex(SkelIn in [[stage_in]],
                           constant SceneUniforms& U [[buffer(1)]]) {
    SkelOut o;
    float z = clamp(in.pos.z, -1.0, 1.0);
    // Perspective : plus z augmente, plus le point est loin → scale < 1
    // RMS pulse fait respirer la profondeur
    float pulse = 1.0 + U.rms * 0.25;
    float persp = 1.0 / (1.0 + z * 0.8);
    float2 xy = in.pos.xy * persp * pulse;
    o.position = float4(xy, 0.0, 1.0);
    o.conf = in.conf;
    o.pid = in.pid;
    o.depth = z;
    return o;
}

// Palette 6 couleurs par personne (turquoise, magenta, jaune, ambre, lilas, vert)
constant float3 PERSON_COLORS[6] = {
    float3(0.0, 1.0, 0.85),    // 0 turquoise
    float3(1.0, 0.3, 0.7),     // 1 magenta
    float3(1.0, 0.9, 0.2),     // 2 jaune
    float3(1.0, 0.55, 0.1),    // 3 ambre
    float3(0.7, 0.5, 1.0),     // 4 lilas
    float3(0.4, 1.0, 0.3),     // 5+ vert (mains)
};

// ===== Mesh overlay (triangles face/hand/body) =====================
// Reuse meme layout que skel : pos.xyz + conf + pid.

vertex SkelOut mesh_vertex(SkelIn in [[stage_in]],
                           constant SceneUniforms& U [[buffer(1)]]) {
    SkelOut o;
    float z = clamp(in.pos.z, -1.0, 1.0);
    float pulse = 1.0 + U.rms * 0.25;
    float persp = 1.0 / (1.0 + z * 0.8);
    float2 xy = in.pos.xy * persp * pulse;
    o.position = float4(xy, 0.0, 1.0);
    o.conf = in.conf;
    o.pid = in.pid;
    o.depth = z;
    return o;
}

fragment float4 mesh_fragment(SkelOut in [[stage_in]]) {
    int pid = int(in.pid + 0.5);
    pid = ((pid % 6) + 6) % 6;
    float3 col = PERSON_COLORS[pid];
    float c = saturate(in.conf);
    // Saturation boost : couleurs vives quand pose detectee
    col = mix(col, col * 1.6, c);
    // Fog par profondeur (proche = plus lumineux)
    float depth_fog = 1.0 - clamp(in.depth + 0.5, 0.0, 1.0) * 0.5;
    col *= depth_fog;
    // Alpha TRES VISIBLE quand confiance haute : 0.85 sur skin, 0.3 fade
    return float4(col, mix(0.3, 0.85, c));
}

fragment float4 skel_fragment(SkelOut in [[stage_in]]) {
    // Skeleton ULTRA visible quand pose detectee : couleur vive + opaque
    int pid = int(in.pid + 0.5);
    pid = ((pid % 6) + 6) % 6;   // modulo positif
    float3 col = PERSON_COLORS[pid] * 1.4;  // saturation boost
    float c = saturate(in.conf);
    // Depth fog : eclaircit ce qui est proche, eteint ce qui est loin
    float depth_fog = 1.0 - clamp(in.depth + 0.5, 0.0, 1.0) * 0.6;
    col *= depth_fog * (0.5 + 0.5 * c);
    // Alpha plein-opaque quand confiance haute (= squelette ultra net)
    return float4(col, mix(0.5, 1.0, c));
}
