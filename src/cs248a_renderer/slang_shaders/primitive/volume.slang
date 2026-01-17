implementing "../primitive.slang";
import math;
import texture;

// The size of each marching step.
static float STEP_SIZE = 0.005;
// The density threshold to consider a hit.
static float DENSITY_THRESHOLD = 0.25;
// The delta used for finite difference normal estimation.
static float FINITE_DIFF_DELTA = 0.001;

public struct Volume
{
    public BoundingBox bound;
    public SharedTexture3D tex;
    public float4x4 modelMatrix;
    public float4x4 invModelMatrix;

    /**
     * Test ray-volume bounding box intersection.
     * @param ray The ray to test against the volume.
     * @param volumeTexBuf The texture buffer contains all the volumetrically represented models in the scene .
     * @return An Optional containing RayHitResult if the ray hits the volume, otherwise an empty Optional.
     */
    public Optional<RayHitResult> hit(Ray ray, SharedTexture3DBuffer<float4> volumeTexBuf)
    {
        // TODO: Student implementation starts here.

        Optional<float2> boundBoxHit = bound.hit(ray);
        if (!boundBoxHit.hasValue)
            return Optional<RayHitResult>();

        for (float i = boundBoxHit.value.x; i < boundBoxHit.value.y; i+=STEP_SIZE) {
            float3 marchingPoint = ray.origin + ray.direction * i;
            float density = volumeTexBuf.trilinearSample(this.tex, this.getUVW(marchingPoint)).a;
            if (density >= DENSITY_THRESHOLD) {
                RayHitResult hitResult;
                hitResult.t = i;
                hitResult.normal = -normalize(float3(
                    volumeTexBuf.trilinearSample(this.tex, this.getUVW(marchingPoint + float3(FINITE_DIFF_DELTA, 0.0, 0.0))).a - 
                        volumeTexBuf.trilinearSample(this.tex, this.getUVW(marchingPoint - float3(FINITE_DIFF_DELTA, 0.0, 0.0))).a,
                    volumeTexBuf.trilinearSample(this.tex, this.getUVW(marchingPoint + float3(0.0, FINITE_DIFF_DELTA, 0.0))).a - 
                        volumeTexBuf.trilinearSample(this.tex, this.getUVW(marchingPoint - float3(0.0, FINITE_DIFF_DELTA, 0.0))).a,
                    volumeTexBuf.trilinearSample(this.tex, this.getUVW(marchingPoint + float3(0.0, 0.0, FINITE_DIFF_DELTA))).a - 
                        volumeTexBuf.trilinearSample(this.tex, this.getUVW(marchingPoint - float3(0.0, 0.0, FINITE_DIFF_DELTA))).a
                ));                
                return Optional<RayHitResult>(hitResult);
            }
        }

        // TODO: Student implementation ends here.

        return Optional<RayHitResult>();
    }

    /**
     * Get the uvw coordinates of a point in local space.
     * @param p The point in world space.
     * @return The uvw coordinates in [0, 1].
     */
    public float3 getUVW(float3 p)
    {
        // Compute uvw coordinates in [0, 1].
        float3 minBound = this.bound.pMin;
        float3 maxBound = this.bound.pMax;
        return (p - minBound) / (maxBound - minBound);
    }
};
