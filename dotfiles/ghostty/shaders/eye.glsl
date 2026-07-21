float draw_eye(vec2 pxCoord) {
    ivec2 p = ivec2(floor((pxCoord - iResolution.xy/2)));
    float alpha = 0;
    
    float width = 3;

    float curve = 40 - p.x * p.x * 0.005;
    if (curve >= 0) {
        float upper = abs(p.y - curve);
        float lower = abs(p.y + curve);
        alpha += (upper < width) ? 1 : 0;
        alpha += (lower < width) ? 1 : 0;
        
        float mult = iFocus * 2 - 1;
        if (abs(p.y - mult * (50 - p.x * p.x * 0.005)) < 12) {
            float line1 = abs(p.x - p.y * mult - 30);
            float line2 = abs(p.x + p.y * mult + 30);
            float line3 = abs(p.x + p.y * mult * 0.5);
            float line4 = abs(p.x - p.y * mult * 0.5);
            alpha += (line1 < width) ? 1 : 0;
            alpha += (line2 < width) ? 1 : 0;
            alpha += (line3 < width) ? 1 : 0;
            alpha += (line4 < width) ? 1 : 0;
        }

        float eye = (p.x * p.x + p.y * p.y) / 4.0;
        alpha += (eye < 360 && eye > 290 || eye < 20) ? iFocus : 0;
    }

    return clamp(alpha, 0, 1);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 col = texture(iChannel0, uv);

    vec2 pos = vec2(iCurrentCursor.x, iCurrentCursor.y);

    float t = iFocus == 1
        ? 1-clamp(4*(iTime - iTimeFocus), 0, 1)
        : 1;

    col.rgb *= (1-t)/2 +0.5;

    if (t > 0) {
        float eye = draw_eye(fragCoord);
        eye *= t;
        col.rgb += eye;
    }

    fragColor = col;
}
