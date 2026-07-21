vec2 boxIntersection(vec3 ro, vec3 rd, vec3 boxSize, out vec3 normal)
{
    vec3 m = 1.0 / rd;
    vec3 n = m * ro;
    vec3 k = abs(m) * boxSize;

    vec3 t1 = -n - k;
    vec3 t2 = -n + k;

    float tN = max(max(t1.x, t1.y), t1.z);
    float tF = min(min(t2.x, t2.y), t2.z);

    if (tN > tF || tF < 0.0) return vec2(-1.0);

    if (tN == t1.x) normal = vec3(-sign(rd.x),0,0);
    else if (tN == t1.y) normal = vec3(0,-sign(rd.y),0);
    else normal = vec3(0,0,-sign(rd.z));

    return vec2(tN, tF);
}

vec2 cubeUV(vec3 p, vec3 n)
{
    vec2 uv;

    if (n.x > 0.5)          // +x
        uv = vec2(-p.z, p.y);
    else if (n.x < -0.5)    // -x
        uv = vec2(p.z, p.y);
    else if (n.y > 0.5)     // +y
        uv = vec2(p.x, -p.z);
    else if (n.y < -0.5)    // -y
        uv = vec2(p.x, p.z);
    else if (n.z > 0.5)     // +z
        uv = vec2(p.x, p.y);
    else                    // -z
        uv = vec2(-p.x, p.y);

    return uv * 0.5 + 0.5;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = (fragCoord * 2.0 - iResolution.xy) / iResolution.y;

    // camera
    vec3 ro = vec3(0.0, 2.0, 3.0);
    vec3 rd = normalize(vec3(uv.x, uv.y - 1.0, -1.0));

    // rotate
    float t = iTime;
    mat2 r = mat2(cos(t),-sin(t),sin(t),cos(t));

    ro.xz *= r;
    rd.xz *= r;

    vec3 normal;
    vec2 hit = boxIntersection(ro, rd, vec3(1.0), normal);

    vec3 col = vec3(0.0);

    if (hit.x > 0.0)
    {
        vec3 p = ro + rd * hit.x;

        vec2 tuv = cubeUV(p, normal);

        col = texture(iChannel0, tuv).rgb;

        float light = dot(normal, normalize(vec3(0.4,0.6,0.75))) * 0.3 + 0.7;
        col *= light;
    }

    fragColor = vec4(col,1.0);
}
