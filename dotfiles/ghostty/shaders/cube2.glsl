float sdBox(vec3 p, vec3 b){
    vec3 q = abs(p) - b;
    return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}

float wireBox(vec3 p, vec3 b, float thickness){
    vec3 d = abs(abs(p) - b);
    float e = min(min(d.x,d.y),d.z);
    return smoothstep(thickness, 0.0, e);
}

mat2 rot(float a){
    float s = sin(a), c = cos(a);
    return mat2(c,-s,s,c);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec4 tex = texture(iChannel0, fragCoord / iResolution.xy);

    if (iFocus > 0) {
        fragColor = tex;
        return;
    }

    vec2 uv = (fragCoord*2.0-iResolution.xy)/iResolution.y;

    vec3 ro = vec3(0.0,0.0,3.0);
    vec3 rd = normalize(vec3(uv,-1.5));

    float t = iTime;

    // rotate ray
    rd.xz *= rot(0);
    rd.xy *= rot(t*0.4);

    float d = 0.0;
    float hit = 0.0;

    for(int i=0;i<60;i++){
        vec3 p = ro + rd*d;

        // cube rotation
        p.xz *= rot(t);
        p.yz *= rot(t*0.7);

        float dist = sdBox(p, vec3(0.8));
        if(dist < 0.01){
            hit = 1.0 - wireBox(p, vec3(0.8), 0.05);
            break;
        }
        d += dist;
        if(d>10.0) break;
    }

    vec4 col = vec4(vec3(hit), 1.0);
    fragColor = col;
}
