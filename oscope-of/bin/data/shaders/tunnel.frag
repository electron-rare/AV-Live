#version 150

// Cylindrical pseudo-3D tunnel. Closed-form mapping from screen UV to
// (angle, depth) — no real raymarching needed for an infinite straight
// tunnel. Twist is added per-depth slice based on lead amplitude.

out vec4 fragColor;

uniform vec2  uRes;
uniform float uTime;
uniform float uTravel;
uniform float uBpm;
uniform float uKick;
uniform float uBass;
uniform float uLead;
uniform float uPad;
// Pilotage par fréquence :
//   uTileZ  — bass loud  → grosses tuiles axe Z (valeur basse, défaut 2)
//   uTileX  — lead loud  → tuiles fines axe angulaire (valeur haute, défaut 16)
//   uDirection — signe du défilement / twist (-1..+1)
//   uRoll      — banking (rotation 2D du plan visible) en radians
//   uPan       — décalage 2D du vanishing point (en unités d'écran -1..+1)
//                permet de "virer" gauche/droite/haut/bas
uniform float uTileZ;
uniform float uTileX;
uniform float uDirection;
uniform float uRoll;
uniform vec2  uPan;

vec3 palette(float t) {
    return 0.5 + 0.5 * cos(6.28318 * (vec3(1.0) * t + vec3(0.0, 0.33, 0.67)));
}

void main() {
    vec2 p = (gl_FragCoord.xy / uRes) * 2.0 - 1.0;
    p.x *= uRes.x / uRes.y;

    // 3D camera orientation : banking (roll) + vanishing point shift (pan).
    // Le roll donne l'illusion qu'on incline la nef, le pan déplace le
    // point de fuite donc le tunnel tourne réellement.
    float cr = cos(uRoll), sr = sin(uRoll);
    p = vec2(cr * p.x - sr * p.y, sr * p.x + cr * p.y);
    p -= uPan;   // décalage du vanishing point

    // Polar coords -> tunnel space
    float r = length(p);
    float a = atan(p.y, p.x);
    if (r < 0.001) r = 0.001;

    // depth z = 1/r so r→0 is far. Travel scrolls slices.
    float z = 1.0 / r + uTravel;
    // Twist: deeper = more rotation, modulated by lead, signé par direction
    a += z * (0.15 + uLead * 0.6) * uDirection;

    // Slice index — densité Z pilotée par bass (uTileZ).
    float slice = floor(z * uTileZ);
    float frac  = fract(z * uTileZ);

    // Brick / ring pattern — densité angulaire pilotée par lead (uTileX).
    float ang  = a / 6.28318 * uTileX;
    float wall = mod(floor(ang) + slice, 2.0);

    // Base color cycles along depth + slight bass push
    vec3 col = palette(slice * 0.07 + uTime * 0.05 + uBass * 0.2);

    // Bright "lamps" every 4 slices
    float lampMask = step(0.92, fract(slice / 4.0));
    float lamp = (1.0 - smoothstep(0.0, 0.4, abs(frac - 0.5))) * lampMask;
    col += vec3(1.0, 0.9, 0.7) * lamp * (0.6 + uKick * 1.5);

    // Wall vs floor stripes alternate brightness
    col *= mix(0.45, 1.0, wall);

    // Add edges between bricks (subtle dark line)
    float edge = smoothstep(0.0, 0.05, abs(frac - 0.5));
    col *= mix(0.7, 1.0, edge);

    // Distance fog : pixels close to center (far away) fade to background
    float fog = smoothstep(0.0, 0.85, r);
    col = mix(vec3(0.0, 0.0, 0.05 + uPad * 0.15), col, fog);

    // Outer ring vignette
    col *= smoothstep(2.0, 0.4, length(p));

    fragColor = vec4(col, 1.0);
}
