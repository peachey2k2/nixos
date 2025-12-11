const float ANIMATION_LEN = 0.03;

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;

    float delta = iTime - iTimeCursorChange;
    delta = clamp(delta, 0.0, ANIMATION_LEN);
    float completion = delta * (1.0/ANIMATION_LEN);

    vec2 pos = mix(iPreviousCursor.xy, iCurrentCursor.xy, completion);

    vec2 bounds = pos - fragCoord;
    bounds.x *= -1;
    vec4 col = texture(iChannel0, uv);
    if (
        bounds.x >= 0.0 &&
        bounds.y >= 0.0 &&
        bounds.x < iCurrentCursor.z &&
        bounds.y < iCurrentCursor.w
    ) {
        col = sqrt(col);
    }
    fragColor = col;
}

