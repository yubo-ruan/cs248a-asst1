implementing "../material.slang";
import math;

public struct SimpleMaterial
{
    public float3 shade(Ray ray, RayHitResult hitResult)
    {
        float NdotL = max(dot(normalize(hitResult.normal), normalize(-ray.direction)), 0.0);
        return float3(1.0, 1.0, 1.0) * NdotL;
    }
}
