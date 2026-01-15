implementing "../primitive.slang";
import math;

public struct Triangle : IRayCastable
{
    public float3[3] vertices;
    public float3[3] normals;
    public float2[3] uvs;
    public float3[3] colors;
    public uint materialId;

    /* Returns the average color of the triangle. */
    public float3 averageColor()
    {
        return (this.colors[0] + this.colors[1] + this.colors[2]) / 3.0;
    }

    /**
     * Test ray-triangle intersection.
     * @param ray The ray to test against the triangle.
     * @return An Optional containing RayHitResult if the ray hits the triangle, otherwise an empty Optional.
     */
    public Optional<RayHitResult> hit(Ray ray)
    {
        // TODO: Student implementation starts here.
        float3 N = cross(vertices[1] - vertices[0], vertices[2] - vertices[0]);
        float c = dot(N, vertices[0]);

        if (abs(dot(N, ray.direction)) < 0.0001) {
            return Optional<RayHitResult>();
        }

        float t = (c - dot(N,ray.origin)) / dot(N, ray.direction);

        if(t< ray.tRange.x || t > ray.tRange.y) {
            return Optional<RayHitResult>();
        }

        float3 P = ray.origin + t * ray.direction;
        float3 C0 = cross(vertices[1] - vertices[0], P - vertices[0]);
        float3 C1 = cross(vertices[2] - vertices[1], P - vertices[1]);
        float3 C2 = cross(vertices[0] - vertices[2], P - vertices[2]);

        float d0 = dot(N, C0);
        float d1 = dot(N, C1);
        float d2 = dot(N, C2);

        // Inside if all same sign (handles both winding orders)
        bool inside = (d0 >= 0 && d1 >= 0 && d2 >= 0) ||
                      (d0 <= 0 && d1 <= 0 && d2 <= 0);

        if (!inside) {
            return Optional<RayHitResult>();
        }


        RayHitResult result;
        result.t = t;
        result.normal = normalize(N);
        return Optional<RayHitResult>(result);

        // TODO: Student implementation ends here.
    }
}
