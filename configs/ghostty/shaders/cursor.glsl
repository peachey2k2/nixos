const float ANIMATION_LEN = 0.1;
const float TRAIL_OPACITY = 0.4;

bool is_inside_box(vec2 frag, vec2 pos, vec2 size) {
    vec2 bounds = pos - frag;
    bounds.x *= -1.0;
    return bounds.x >= 0.0 && bounds.y >= 0.0 && bounds.x < size.x && bounds.y < size.y;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 col = texture(iChannel0, uv);

    float delta = iTime - iTimeCursorChange;
    float completion = clamp(delta, 0.0, ANIMATION_LEN) / ANIMATION_LEN;
    completion = sqrt(completion); // Ease out

    vec2 start = iPreviousCursor.xy;
    vec2 end = iCurrentCursor.xy;
    vec2 start_size = iPreviousCursor.zw;
    vec2 end_size = iCurrentCursor.zw;

    vec2 head_pos = mix(start, end, completion);
    vec2 head_size = mix(start_size, end_size, completion);
    vec3 cursor_color = mix(iCurrentCursorColor.rgb, iPreviousCursorColor.rgb, completion);

    if (is_inside_box(fragCoord, head_pos, head_size)) {
        vec3 brighten = sqrt(col.rgb * 2.0) / sqrt(2.0);
        col.rgb = mix(brighten, cursor_color, 0.3);
    } 

    else if (completion < 1.0) {
        vec2 move = end - start;
        
        if (dot(move, move) > 1.0) {
            vec2 center = start_size / 2.0; 
            center.y *= -1.0; 
            
            vec2 p = fragCoord - (start + center);
            
            float t = dot(p, move) / dot(move, move);
            
            if (t > 0.0 && t < completion) {
                
                vec2 trail_pos = mix(start, end, t);
                vec2 trail_size = mix(start_size, end_size, t);

                if (is_inside_box(fragCoord, trail_pos, trail_size)) {
                    float dist = completion - t;
                    float fade = (1.0 - smoothstep(0.0, 0.5, dist)) * TRAIL_OPACITY;
                    
                    col.rgb = mix(col.rgb, cursor_color, fade);
                }
            }
        }
    }

    fragColor = col;
}
