#version 150

// Boing Ball — Amiga 1984 RJ Mical & Dale Luck demo. Sphere checker
// rouge/blanc qui rebondit en damier 8 méridiens × 8 parallèles.
// Audio-reactive : shadow/light + bounce vertical sur kick.

out vec4 fragColor;

uniform vec2  uRes;
uniform float uTime;
uniform float uBass;
uniform float uMid;
uniform float uTreble;
uniform float uKick;
uniform float uBpm;

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5 * uRes) / uRes.y;

    // Bounce vertical : la boule tape le sol au tempo du kick.
    float bouncePhase = uTime * (1.6 + uBpm * 0.005);
    float bounce = abs(sin(bouncePhase));   // 0..1, 0 quand au sol
    bounce = pow(bounce, 0.6);              // accentue le rebond
    vec2 ballC = vec2(0.0, -0.18 + bounce * 0.45);

    // Sphere SDF 2D : distance au centre
    float ballR = 0.40 + uKick * 0.06;
    float d = length(uv - ballC);

    // Sol horizontal
    float floorY = -0.6;
    float floorD = uv.y - floorY;

    // Background grille type 1984 Amiga
    vec3 bg = vec3(0.85, 0.78, 0.70);   // crème vintage
    float gridX = abs(fract(uv.x * 6.0 + 0.5) - 0.5);
    float gridY = abs(fract(uv.y * 6.0 + 0.5) - 0.5);
    float grid = smoothstep(0.04, 0.0, min(gridX, gridY));
    bg = mix(bg, vec3(0.55, 0.20, 0.20), grid * 0.6);

    // Sol gradient (perspective)
    if (uv.y < floorY) {
        float fade = smoothstep(floorY, floorY - 0.6, uv.y);
        bg = mix(bg, vec3(0.30, 0.10, 0.12), fade);
    }

    vec3 col = bg;

    if (d < ballR) {
        // Sur la sphère — calcule normale 3D pour checker pattern
        float z = sqrt(ballR*ballR - d*d) / ballR;
        // Coords sphériques
        vec2 p = (uv - ballC) / ballR;
        float lon = atan(p.x, z) + uTime * (1.5 + uMid * 1.2);  // rotation
        float lat = asin(p.y);
        // Damier 8x8
        float mer = floor(lon / 3.14159 * 4.0);
        float par = floor(lat / 3.14159 * 8.0);
        bool checkBlack = mod(mer + par, 2.0) > 0.5;
        vec3 ballCol = checkBlack ? vec3(0.95, 0.95, 0.95)
                                  : vec3(0.85, 0.10, 0.10);
        // Lambert lumière en haut-gauche
        float lambert = max(0.2, dot(normalize(vec3(p.x, p.y, z)),
                                     normalize(vec3(-0.4, 0.5, 0.7))));
        ballCol *= 0.4 + 0.7 * lambert;
        // Spéculaire blanc
        float spec = pow(max(0.0,
            dot(reflect(vec3(0,0,-1), normalize(vec3(p.x, p.y, z))),
                normalize(vec3(-0.4, 0.5, 0.7)))), 16.0);
        ballCol += vec3(1.0) * spec * 0.6;
        col = ballCol;
    }
    // Ombre au sol — disque allongé qui suit la boule
    float shadowD = length(vec2(uv.x - ballC.x, (uv.y - floorY) * 4.0));
    float shadowR = ballR * (1.2 - bounce * 0.4);
    float shadow = smoothstep(shadowR, shadowR * 0.5, shadowD);
    if (uv.y < floorY + 0.05 && uv.y > floorY - 0.15) {
        col *= mix(1.0, 0.4, shadow * (1.0 - bounce));
    }

    fragColor = vec4(col, 1.0);
}
