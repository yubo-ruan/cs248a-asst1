import math;
import texture;
import material;
import model;
import primitive;


public struct RendererUniform
{
    // Camera parameters.
    public Camera camera;
    // Ambient color, used when no ray hits a primitive
    public float4 ambientColor;
    // Ray samples per pixel
    public uint sqrtSpp;
    // Primitives.
    public StructuredBuffer<Triangle> triangleBuf;
    public uint triangleCount;
    
    public SharedTexture3DBuffer<float4> volumeTexBuf;
    public StructuredBuffer<Volume> volumeBuf;
    public uint volumeCount;
    public SDFBuffer sdfBuf;
    // Acceleration structure.
    public bool useBVH;
    public BVH<Triangle> bvh;

    public bool renderDepth;
    public bool renderNormal;
}

static uint MAX_STEPS = 100;
static float EPSILON = 1e-6;

/**
 * Sample the scene at the given uv coordinate.
 * @param uv The normalized uv coordinate from (0, 0) in the bottom-left to (1, 1) in the top-right.
 * @param uniforms The renderer uniform containing camera, sampling, and scene information.
 * @return The color of the ray sample at the given uv coordinate.
 */
public float4 sample(float2 uv, RendererUniform uniforms)
{
    // We generate a camera ray for the given uv coordinate.
    // You need to implement the `generateRay` function in `Camera` struct in `src/cs248a_renderer/slang_shaders/model/camera.slang`
    Ray ray = uniforms.camera.generateRay(uv);
    RayHitResult result;

    // TODO: Student implementation starts here.
    float closestT = float.maxValue;

    for (uint i = 0; i < uniforms.triangleCount; i++) {
        Triangle triangle = uniforms.triangleBuf[i];
        Optional<RayHitResult> hitResult = triangle.hit(ray);


        if (hitResult.hasValue && hitResult.value.t < closestT) {
            closestT = hitResult.value.t;
            result = RayHitResult(closestT, hitResult.value.normal);
        }
    }

    for (uint i = 0; i < uniforms.volumeCount; i++) {
        Volume vol = uniforms.volumeBuf[i];
        Optional<RayHitResult> hitResult = vol.hit(ray, uniforms.volumeTexBuf);
        

        if (hitResult.hasValue && hitResult.value.t < closestT) {
            closestT = hitResult.value.t;
            result = RayHitResult(closestT, hitResult.value.normal);
        }
    }

    for (uint i = 0; i < uniforms.sdfBuf.sphereCount; i++) {
        SphereSDF sphere = uniforms.sdfBuf.spheres[i];
        for (float d = ray.tRange.x; d < ray.tRange.y; d += sphere.sdf(ray.origin + d * ray.direction)) {
            if (sphere.sdf(ray.origin + d * ray.direction) <= EPSILON) {
                if (d < closestT) {
                    closestT = d;
                    result = RayHitResult(d, sphere.normal(ray.origin + d * ray.direction));
                    break;
                }
            }
        }
    }

    for (uint i = 0; i < uniforms.sdfBuf.cubeCount; i++) {
        CubeSDF cube = uniforms.sdfBuf.cubes[i];
        for (float d = ray.tRange.x; d < ray.tRange.y; d += cube.sdf(ray.origin + d * ray.direction)) {
            if (cube.sdf(ray.origin + d * ray.direction) <= EPSILON) {
                if (d < closestT) {
                    closestT = d;
                    result = RayHitResult(d, cube.normal(ray.origin + d * ray.direction));
                    break;
                }
            }
        }
    }

    if (uniforms.sdfBuf.renderCustomSDF) {
        CustomSDF custom = uniforms.sdfBuf.customSDF;
        float t = ray.tRange.x;
        for (uint step = 0; step < MAX_STEPS && t < ray.tRange.y; step++) {
            float3 p = ray.origin + t * ray.direction;
            float dist = custom.sdf(p);
            if (dist <= EPSILON) {
                if (t < closestT) {
                    closestT = t;
                    result = RayHitResult(t, custom.normal(p));
                }
                break;
            }
            t += dist;
        }
    }
    

    if (closestT >= float.maxValue)
        return uniforms.ambientColor;


    // TODO: Student implementation ends here.

    if (uniforms.renderDepth)
    {
        // Map depth to [0, 1] range for visualization
        return float4(float3(result.t), 1.0);
    }

    if (uniforms.renderNormal)
    {
        // Map normal from [-1, 1] to [0, 1] range for visualization
        return float4(result.normal * 0.5 + 0.5, 1.0);
    }

    // Once you have the intersection result, use the following code to shade (calculate color) for the ray.
    // The shading function needs the camera ray and the intersection result.
    SimpleMaterial simpleMaterial;
    float3 color = simpleMaterial.shade(ray, result);
    return float4(color, 1.0);    
}

/**
 * The entry point of the renderer.
 * @param tid The 2D coordinate of the current thread. Ranges from (0, 0) to (canvasSize.x - 1, canvasSize.y - 1).
 * @param uniforms The renderer uniform containing camera, sampling, and scene information.
 * @return The color of the pixel at the given thread coordinate.
 */
public float4 render(uint2 tid, RendererUniform uniforms)
{
    // TODO: Student implementation starts here.

    // Basic version: no supersampling (remove this implementation once you implement supersampling)

    float4 finalColor = float4(0.0, 0.0, 0.0, 0.0);
    for (uint i = 0; i < uniforms.sqrtSpp; i++) {
        for (uint j = 0; j < uniforms.sqrtSpp; j++) {
            float2 offset = (float2(i, j) + 0.5) / float2(uniforms.sqrtSpp);
            float2 uv = (float2(tid) + offset) / float2(uniforms.camera.canvasSize);
            finalColor += sample(uv, uniforms);
        }
    }


    return finalColor / float(uniforms.sqrtSpp * uniforms.sqrtSpp);

    // TODO: Student implementation ends here.
}
