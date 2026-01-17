implementing "../texture.slang";

public struct SharedTexture3DBuffer<T>
    where T : IFloat
{
    public StructuredBuffer<T> buffer;

    T getBufferValue(SharedTexture3D tex, uint3 voxelCoord)
    {
        uint3 texSize = tex.size;
        uint offset = tex.offset;
        uint index = voxelCoord.z * texSize.y * texSize.x +
                     voxelCoord.y * texSize.x +
                     voxelCoord.x;
        return buffer[offset + index];
    }

    /**
     * Sample the texture at the given uvw coordinates using nearest neighbor interpolation.
     * @param tex The texture to sample.
     * @param uvw The uvw coordinates to sample the texture at.
     * @return The sampled value.
     */
    public T pointSample(SharedTexture3D tex, float3 uvw)
    {
        // TODO: Student implementation starts here.
        T pointSampledValue = this.getBufferValue(tex, uint3(
            min(uint(floor(uvw.x * tex.size.x)), tex.size.x - 1),
            min(uint(floor(uvw.y * tex.size.y)), tex.size.y - 1),
            min(uint(floor(uvw.z * tex.size.z)), tex.size.z - 1)
        ));

        return pointSampledValue;

        // TODO: Student implementation ends here.
    }

    /**
     * Sample the texture at the given uvw coordinates using trilinear interpolation.
     * @param tex The texture to sample.
     * @param uvw The uvw coordinates to sample the texture at.
     * @return The sampled value.
    **/
    public T trilinearSample(SharedTexture3D tex, float3 uvw)
    {
        // TODO: Student implementation starts here.

        T pointSamepledWeight = T(0);
        int3 baseVoxel = int3(floor(uvw * tex.size));
        float3 weight = (uvw * tex.size) - baseVoxel;

        for (int i = 0; i < 2; i++) {
            for (int j = 0; j < 2; j++) {
                for (int k = 0; k < 2; k++) {
                    T pointSampledValue = this.getBufferValue(tex, uint3(
                        baseVoxel.x + i,
                        baseVoxel.y + j,
                        baseVoxel.z + k
                    ));
                    float wx = (i == 0) ? (1.0 - weight.x) : weight.x;
                    float wy = (j == 0) ? (1.0 - weight.y) : weight.y;
                    float wz = (k == 0) ? (1.0 - weight.z) : weight.z;
                    pointSamepledWeight = pointSamepledWeight + pointSampledValue * T(wx * wy * wz);
                }
            }
        }

        return pointSamepledWeight;

        // TODO: Student implementation ends here.
    }
}

public struct SharedTexture3D
{
    public uint3 size;
    public uint offset;
}

