// ---------------------------------------------------------------------------
// Core triplanar colour sample
// ---------------------------------------------------------------------------
float4 triplanar(float3 vertPos, float3 normal, float scale,
                 Texture2D tex, SamplerState samplerTex)
{
    float2 uvX = vertPos.zy * scale;
    float2 uvY = vertPos.xz * scale;
    float2 uvZ = vertPos.xy * scale;
    
    float4 colX = SAMPLE_TEXTURE2D(tex, samplerTex, uvX);
    float4 colY = SAMPLE_TEXTURE2D(tex, samplerTex, uvY);
    float4 colZ = SAMPLE_TEXTURE2D(tex, samplerTex, uvZ);

    // Square normal to keep all values positive and sharpen the blend
    float3 blendWeight = normal * normal;
    // Normalise so x + y + z = 1
    blendWeight /= dot(blendWeight, 1);

    return colX * blendWeight.x + colY * blendWeight.y + colZ * blendWeight.z;
}

// ---------------------------------------------------------------------------
// Triplanar colour sample with per-axis offset
// ---------------------------------------------------------------------------
float4 triplanarOffset(float3 vertPos, float3 normal, float3 scale,
                       Texture2D tex, SamplerState samplerTex, float2 offset)
{
    float3 scaledPos = vertPos / scale;

    float4 colX = SAMPLE_TEXTURE2D(tex, samplerTex, scaledPos.zy + offset);
    float4 colY = SAMPLE_TEXTURE2D(tex, samplerTex, scaledPos.xz + offset);
    float4 colZ = SAMPLE_TEXTURE2D(tex, samplerTex, scaledPos.xy + offset);

    float3 blendWeight = normal * normal;
    blendWeight /= dot(blendWeight, 1);

    return colX * blendWeight.x + colY * blendWeight.y + colZ * blendWeight.z;
}

// ---------------------------------------------------------------------------
// Utility: object-space vector → tangent space
// ---------------------------------------------------------------------------
float3 ObjectToTangentVector(float4 tangent, float3 normal, float3 objectSpaceVector)
{
    float3 normalizedTangent = normalize(tangent.xyz);
    float3 binormal = cross(normal, normalizedTangent) * tangent.w;
    float3x3 rot = float3x3(normalizedTangent, binormal, normal);
    return mul(rot, objectSpaceVector);
}

// ---------------------------------------------------------------------------
// Reoriented Normal Mapping blend
// http://blog.selfshadow.com/publications/blending-in-detail/
// Takes normals in [-1, 1] range (not unsigned maps)
// ---------------------------------------------------------------------------
float3 blend_rnm(float3 n1, float3 n2)
{
    n1.z += 1;
    n2.xy = -n2.xy;
    return n1 * dot(n1, n2) / n1.z - n2;
}

// ---------------------------------------------------------------------------
// Triplanar normal sample — result in obj/world space
// Based on: medium.com/@bgolus/normal-mapping-for-a-triplanar-shader-10bf39dca05a
// ---------------------------------------------------------------------------
float3 triplanarNormal(float3 vertPos, float3 normal, float3 scale, float2 offset,
                       Texture2D normalMap, SamplerState samplerNormalMap)
{
    float3 absNormal = abs(normal);

    // Blend weight — pow(4) sharpens the transition between axes
    float3 blendWeight = saturate(pow(normal, 4));
    blendWeight /= dot(blendWeight, 1);

    float2 uvX = vertPos.zy * scale + offset;
    float2 uvY = vertPos.xz * scale + offset;
    float2 uvZ = vertPos.xy * scale + offset;

    // Sample and unpack each face's normal map
    float3 tangentNormalX = UnpackNormal(SAMPLE_TEXTURE2D(normalMap, samplerNormalMap, uvX));
    float3 tangentNormalY = UnpackNormal(SAMPLE_TEXTURE2D(normalMap, samplerNormalMap, uvY));
    float3 tangentNormalZ = UnpackNormal(SAMPLE_TEXTURE2D(normalMap, samplerNormalMap, uvZ));

    // Swizzle into tangent space and blend with RNM
    tangentNormalX = blend_rnm(half3(normal.zy, absNormal.x), tangentNormalX);
    tangentNormalY = blend_rnm(half3(normal.xz, absNormal.y), tangentNormalY);
    tangentNormalZ = blend_rnm(half3(normal.xy, absNormal.z), tangentNormalZ);

    // Apply input normal sign to tangent-space Z
    float3 axisSign = sign(normal);
    tangentNormalX.z *= axisSign.x;
    tangentNormalY.z *= axisSign.y;
    tangentNormalZ.z *= axisSign.z;

    return normalize(
        tangentNormalX.zyx * blendWeight.x +
        tangentNormalY.xzy * blendWeight.y +
        tangentNormalZ.xyz * blendWeight.z
    );
}

// ---------------------------------------------------------------------------
// Triplanar normal → tangent space (two overloads matching the original API)
// ---------------------------------------------------------------------------
float3 triplanarNormalTangentSpace(float3 vertPos, float3 normal, float3 scale,
                                   float4 tangent,
                                   Texture2D normalMap, SamplerState samplerNormalMap)
{
    float3 textureNormal = triplanarNormal(vertPos, normal, scale, 0, normalMap, samplerNormalMap);
    return ObjectToTangentVector(tangent, normal, textureNormal);
}

float3 triplanarNormalTangentSpace(float3 vertPos, float3 normal, float3 scale,
                                   float2 offset, float4 tangent,
                                   Texture2D normalMap, SamplerState samplerNormalMap)
{
    float3 textureNormal = triplanarNormal(vertPos, normal, scale, offset,
                                           normalMap, samplerNormalMap);
    return ObjectToTangentVector(tangent, normal, textureNormal);
}
