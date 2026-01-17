import math;
import model;
import primitive;

/**
 * Fill a solid red color.
 * @param tid The 2D coordinate of the current thread. Ranges from (0, 0) to (canvasSize.x - 1, canvasSize.y - 1).
 * @return The color red as a float4 vector.
 */
public float4 fillRed(uint2 tid)
{
    // Return the color as a float4 vector (red, green, blue, alpha).
    // In this example, we set alpha to 1 to indicate a fully opaque pixel.
    // We'll cover alpha, transparency later in the class.
    return float4(1.0, 0.0, 0.0, 1.0);
}

/**
 * Fill a uv gradient pattern.
 * @param tid The 2D coordinate of the current thread. Ranges from (0, 0) to (canvasSize.x - 1, canvasSize.y - 1).
 * @param canvasSize The size of the output image in pixels.
 * @return The color corresponding to the uv(xy) coordinate of the pixel.
 */
public float4 fillGradient(uint2 tid, uint2 canvasSize)
{
    // TODO: Student implementation starts here.

    // Normalize tid to range [0, 1] by dividing by canvas size
    float2 uv = float2(tid) / float2(canvasSize);
    // Return uv.x as red, uv.y as green, 0 as blue, 1 as alpha
    return float4(uv.x, uv.y, 0.0, 1.0);

    // TODO: Student implementation ends here.
}

/**
 * Fill a checkerboard pattern.
 * @param tid The 2D coordinate of the current thread. Ranges from (0, 0) to (canvasSize.x - 1, canvasSize.y - 1).
 * @param canvasSize The size of the output image in pixels.
 * @param numSquares The number of squares along each axis.
 * @return The color white or black depending on the checkerboard pattern.
 */
public float4 fillCheckerboard(uint2 tid, uint2 canvasSize, uint numSquares)
{
    // TODO: Student implementation starts here.

    // Normalize to [0, 1] then scale by number of squares
    float2 pt = float2(tid) / float2(canvasSize);
    uint2 index = uint2(pt * float(numSquares));

    // Checkerboard pattern: if sum of indices is even → white, odd → black
    if ((index.x + index.y) % 2 == 0) {
        return float4(1.0, 1.0, 1.0, 1.0);
    }
    return float4(0.0, 0.0, 0.0, 1.0);
    

    // TODO: Student implementation ends here.
}

/**
 * Rasterize a single triangle.
 * @param tid The 2D coordinate of the current thread. Ranges from (0, 0) to (canvasSize.x - 1, canvasSize.y - 1).
 * @param canvasSize The size of the output image in pixels.
 * @param v0 The first vertex of the triangle in normalized coordinates.
 * @param v1 The second vertex of the triangle in normalized coordinates.
 * @param v2 The third vertex of the triangle in normalized coordinates.
 * @return The color white if the pixel is inside the triangle, otherwise black.
 */
public float4 triangleRasterizer(uint2 tid, uint2 canvasSize, float2 v0, float2 v1, float2 v2)
{
    // TODO: Student implementation starts here.

    float2 p = float2(tid) / float2(canvasSize); // Normalize tid to [0, 1]
    float e0 = (p.x - v0.x) * (v1.y - v0.y) - (p.y - v0.y) * (v1.x - v0.x); // cross product for edge v0->v0
    float e1 = (p.x - v1.x) * (v2.y - v1.y) - (p.y - v1.y) * (v2.x - v1.x); //cross product for edge v1->v1
    float e2 = (p.x - v2.x) * (v0.y - v2.y) - (p.y - v2.y) * (v0.x - v2.x); //cross product for edge v2->v2

    bool inside = (e0 <= 0 && e1 <= 0 && e2 <= 0 || e0 >= 0 && e1 >= 0 && e2 >= 0);
    if (inside) {
        return float4(1.0, 1.0, 1.0, 1.0);  // White
    } else {
        return float4(0.0, 0.0, 0.0, 1.0);  // Black
    }

    // TODO: Student implementation ends here.
}

/**
 * Test ray-triangle intersection for a single triangle.
 * @param tid The 2D coordinate of the current thread. Ranges from (0, 0) to (canvasSize.x - 1, canvasSize.y - 1).
 * @param canvasSize The size of the output image in pixels.
 * @param triangles A buffer containing triangles to test against. Only the first triangle is used in this function.
 * @return The color of the triangle if hit, otherwise black.
 */
public float4 rayTriangleTest(uint2 tid, uint2 canvasSize, StructuredBuffer<Triangle> triangles)
{
    // Get the first triangle in the buffer.
    Triangle triangle = triangles[0];
    // We generate rays with origin from (0, 0, 0) to (1, 1, 0) and direction towards the negative z axis (0, 0, -1).
    float2 uv = float2(tid) / float2(canvasSize); //normalized uv coordinates
    Ray ray = Ray(float3(uv, 0.0), float3(0.0, 0.0, -1.0), float2(0.0, float.maxValue)); //ray setup
    // How can we make sure the rays are set up correctly? Just return the value as color.
    // return float4(ray.origin.xy, 0.0, 1.0);
    Optional<RayHitResult> hitResult = triangle.hit(ray);
    if (hitResult.hasValue)
    {
        return float4(triangle.averageColor(), 1.0); // Return triangle color if hit
    }
    else
    {
        return float4(0.0, 0.0, 0.0, 1.0); // Black color if no hit
    }
}

/**
 * Test ray-triangle intersection for multiple triangles.
 * @param tid The 2D coordinate of the current thread. Ranges from (0, 0) to (canvasSize.x - 1, canvasSize.y - 1).
 * @param canvasSize The size of the output image in pixels.
 * @param triangles A buffer containing triangles to test against.
 * @param triangleCount The number of triangles in the buffer.
 * @return The color of the closest triangle if hit, otherwise black.
 */
public float4 rayTrianglesTest(uint2 tid, uint2 canvasSize, StructuredBuffer<Triangle> triangles, uint triangleCount)
{
    // We generate rays with origin from (0, 0, 0) to (1, 1, 0) and direction towards the negative z axis (0, 0, -1).
    float2 uv = float2(tid) / float2(canvasSize);
    Ray ray = Ray(float3(uv, 0.0), float3(0.0, 0.0, -1.0), float2(0.0, float.maxValue));

    // TODO: Student implementation starts here.

    float closestT = float.maxValue;
    float3 closestColor = float3(0.0);

    for (uint i = 0; i < triangleCount; i++) {
        Triangle triangle = triangles[i];
        Optional<RayHitResult> hitResult = triangle.hit(ray);

        if (hitResult.hasValue ) {
            closestT = hitResult.value.t;
            closestColor = triangle.averageColor();
        }
    }

    if (closestT < float.maxValue) {
        return float4(closestColor, 1.0);  // Hit something
    } else {
        return float4(0.0, 0.0, 0.0, 1.0);  // No hits
    }

    // TODO: Student implementation ends here.
}
