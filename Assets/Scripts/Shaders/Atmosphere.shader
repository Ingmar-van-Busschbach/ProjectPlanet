Shader "PostProcessing/Atmosphere"
{
    Properties
    {
        _BakedOpticalDepth("Baked Optical Depth", 2D) = "white" {}
        _BlueNoise("Blue Noise", 2D) = "white" {}
        dirToSun ("dirToSun", Vector) = (0.000000,0.000000,0.000000,0.000000)
        planetCentre ("planetCentre", Vector) = (0.000000,0.000000,0.000000,0.000000)
        atmosphereRadius ("atmosphereRadius", Float) = 0.000000
        oceanRadius ("oceanRadius", Float) = 0.000000
        planetRadius ("planetRadius", Float) = 0.000000
        numInScatteringPoints ("numInScatteringPoints", Float) = 0.000000
        numOpticalDepthPoints ("numOpticalDepthPoints", Float) = 0.000000
        intensity ("intensity", Float) = 0.000000
        scatteringCoefficients ("scatteringCoefficients", Vector) = (0.000000,0.000000,0.000000,0.000000)
        ditherStrength ("ditherStrength", Float) = 0.000000
        ditherScale ("Dither Scale", Float) = 0.000000
        densityFalloff ("densityFalloff", Float) = 0.000000
        [HideInInspector][NoScaleOffset]unity_Lightmaps("unity_Lightmaps", 2DArray) = "" {}
        [HideInInspector][NoScaleOffset]unity_LightmapsInd("unity_LightmapsInd", 2DArray) = "" {}
        [HideInInspector][NoScaleOffset]unity_ShadowMasks("unity_ShadowMasks", 2DArray) = "" {}
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalPipeline"
        }
        Pass
        {
            Name "DrawProcedural"
            Cull Off
            Blend Off
            ZTest Off
            ZWrite Off
            
            HLSLPROGRAM
            
            // Pragmas
            #pragma target 3.0
            #pragma vertex vert
            #pragma fragment frag
            
            // Keywords
            #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT
            #define FULLSCREEN_SHADERGRAPH
            
            // Defines
            #define ATTRIBUTES_NEED_TEXCOORD0
            #define ATTRIBUTES_NEED_TEXCOORD1
            #define ATTRIBUTES_NEED_VERTEXID
            #define VARYINGS_NEED_POSITION_WS
            #define VARYINGS_NEED_TEXCOORD0
            #define VARYINGS_NEED_TEXCOORD1
            
            #define REQUIRE_DEPTH_TEXTURE
            #define REQUIRE_NORMAL_TEXTURE
            
            #define SHADERPASS SHADERPASS_DRAWPROCEDURAL
            
            // Includes
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/DebugMipmapStreamingMacros.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
            #include "../Includes/Math.cginc"
            
            // --------------------------------------------------
            // Structs and Packing
            
            struct Attributes
            {
                uint vertexID : VERTEXID_SEMANTIC;
            };
            struct SurfaceDescriptionInputs
            {
                float3 WorldSpacePosition;
                float4 ScreenPosition;
                float2 NDCPosition;
                float2 PixelPosition;
            };
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float4 texCoord0;
                float4 texCoord1;
            };
            struct PackedVaryings
            {
                float4 positionCS : SV_POSITION;
                float4 texCoord0 : INTERP0;
                float4 texCoord1 : INTERP1;
            };
            
            PackedVaryings PackVaryings(Varyings input)
            {
                PackedVaryings output;
                output.positionCS = input.positionCS;
                output.texCoord0.xyzw = input.texCoord0;
                output.texCoord1.xyzw = input.texCoord1;
                return output;
            }
            
            Varyings UnpackVaryings(PackedVaryings input)
            {
                Varyings output;
                output.positionCS = input.positionCS;
                output.texCoord0 = input.texCoord0.xyzw;
                output.texCoord1 = input.texCoord1.xyzw;
                return output;
            }

            // --------------------------------------------------
            // Object and Global properties

            float _FlipY;
            
            TEXTURE2D_X(_BlitTexture);
            float4 Unity_Universal_SampleBuffer_BlitSource_float(float2 uv)
            {
                uint2 pixelCoords = uint2(uv * _ScreenSize.xy);
                return LOAD_TEXTURE2D_X_LOD(_BlitTexture, pixelCoords, 0);
            }

            // --------------------------------------------------
            // Atmosphere properties

            TEXTURE2D(_BlueNoise);          SAMPLER(sampler_BlueNoise);
            TEXTURE2D(_BakedOpticalDepth);  SAMPLER(sampler_BakedOpticalDepth);

            float3 dirToSun;

            float3 planetCentre;
            float atmosphereRadius;
            float oceanRadius;
            float planetRadius;

            int   numInScatteringPoints;
            int   numOpticalDepthPoints;
            float intensity;
            float4 scatteringCoefficients;
            float ditherStrength;
            float ditherScale;
            float densityFalloff;

            // --------------------------------------------------
            // Atmosphere helpers

            float2 squareUV(float2 uv)
            {
                float width  = _ScreenParams.x;
                float height = _ScreenParams.y;
                float scale  = 1000;
                return float2((uv.x * width) / scale, (uv.y * height) / scale);
            }

            float densityAtPoint(float3 densitySamplePoint)
            {
                float heightAboveSurface = length(densitySamplePoint - planetCentre) - planetRadius;
                float height01     = heightAboveSurface / (atmosphereRadius - planetRadius);
                float localDensity = exp(-height01 * densityFalloff) * (1 - height01);
                return localDensity;
            }

            float opticalDepth(float3 rayOrigin, float3 rayDir, float rayLength) {
				float3 densitySamplePoint = rayOrigin;
				float stepSize = rayLength / (numOpticalDepthPoints - 1);
				float opticalDepth = 0;

				for (int i = 0; i < numOpticalDepthPoints; i ++) {
					float localDensity = densityAtPoint(densitySamplePoint);
					opticalDepth += localDensity * stepSize;
					densitySamplePoint += rayDir * stepSize;
				}
				return opticalDepth;
			}

            float opticalDepthBaked(float3 rayOrigin, float3 rayDir)
            {
                float height   = length(rayOrigin - planetCentre) - planetRadius;
                float height01 = saturate(height / (atmosphereRadius - planetRadius));
                float uvX      = 1 - (dot(normalize(rayOrigin - planetCentre), rayDir) * 0.5 + 0.5);
                return SAMPLE_TEXTURE2D_LOD(_BakedOpticalDepth, sampler_BakedOpticalDepth, float2(uvX, height01), 0).r;
            }

            float opticalDepthBaked2(float3 rayOrigin, float3 rayDir, float rayLength)
            {
                float3 endPoint = rayOrigin + rayDir * rayLength;
                float  d        = dot(rayDir, normalize(rayOrigin - planetCentre));

                const float blendStrength = 1.5;
                float w = saturate(d * blendStrength + 0.5);

                float d1 = opticalDepthBaked(rayOrigin, rayDir)   - opticalDepthBaked(endPoint, rayDir);
                float d2 = opticalDepthBaked(endPoint, -rayDir)   - opticalDepthBaked(rayOrigin, -rayDir);

                return lerp(d2, d1, w);
            }

            float3 calculateLight(float3 rayOrigin, float3 rayDir, float rayLength,
                                  float3 originalCol, float2 uv)
            {
                float blueNoise = SAMPLE_TEXTURE2D_LOD(_BlueNoise, sampler_BlueNoise,
                                      squareUV(uv) * ditherScale, 0).r;
                blueNoise = (blueNoise - 0.5) * ditherStrength;

                float3 inScatterPoint       = rayOrigin;
                float  stepSize             = rayLength / (numInScatteringPoints - 1);
                float3 inScatteredLight     = 0;
                float  viewRayOpticalDepth  = 0;

                for (int i = 0; i < numInScatteringPoints; i++)
                {
                    float sunRayOpticalDepth = opticalDepthBaked(
                        inScatterPoint + dirToSun * ditherStrength, dirToSun);
                    float localDensity       = densityAtPoint(inScatterPoint);
                    viewRayOpticalDepth      = opticalDepth(rayOrigin, rayDir, stepSize * i);

                    float3 transmittance = exp(-(sunRayOpticalDepth + viewRayOpticalDepth)
                                              * scatteringCoefficients.rgb);

                    inScatteredLight += localDensity * transmittance;
                    inScatterPoint   += rayDir * stepSize;
                }
                inScatteredLight *= scatteringCoefficients.rgb * intensity * stepSize / planetRadius;
                inScatteredLight += blueNoise * 0.01;

                // Attenuate reflected light (hacky, see original TODO)
                const float brightnessAdaptionStrength      = 0.15;
                const float reflectedLightOutScatterStrength = 3;
                float brightnessAdaption     = dot(inScatteredLight, 1) * brightnessAdaptionStrength;
                float brightnessSum          = viewRayOpticalDepth * intensity
                                               * reflectedLightOutScatterStrength + brightnessAdaption;
                float reflectedLightStrength = exp(-brightnessSum);
                float hdrStrength            = saturate(dot(originalCol, 1) / 3 - 1);
                reflectedLightStrength       = lerp(reflectedLightStrength, 1, hdrStrength);
                float3 reflectedLight        = originalCol * reflectedLightStrength;

                return reflectedLight + inScatteredLight;
            }

            // --------------------------------------------------
            // Surface description
            
            struct SurfaceDescription
            {
                float3 BaseColor;
                float  Alpha;
            };
            
            SurfaceDescription SurfaceDescriptionFunction(SurfaceDescriptionInputs IN)
            {
                SurfaceDescription surface;

                const float2 uv           = IN.NDCPosition.xy;
                const float4 originalCol  = Unity_Universal_SampleBuffer_BlitSource_float(uv);

                // Reconstruct view ray from the world-space position already computed
                // in BuildSurfaceDescriptionInputs (mirrors the original viewVector logic).
                float3 rayOrigin = GetCameraPositionWS();
                float3 viewVec   = IN.WorldSpacePosition - rayOrigin;
                float3 rayDir    = normalize(viewVec);

                // Scene depth as linear world-space distance along the view ray
                float linearDepth  = LinearEyeDepth(
                    SHADERGRAPH_SAMPLE_SCENE_DEPTH(uv), _ZBufferParams);
                float3 cameraFwd   = -UNITY_MATRIX_V[2].xyz;
                float  sceneDepth  = linearDepth / dot(rayDir, cameraFwd) * length(viewVec)
                                     / linearDepth;
                // Simpler equivalent: project linear depth onto the ray
                sceneDepth = LinearEyeDepth(SHADERGRAPH_SAMPLE_SCENE_DEPTH(uv), _ZBufferParams)
                             * length(viewVec) / dot(normalize(viewVec), cameraFwd);

                float dstToOcean   = raySphere(planetCentre, oceanRadius,   rayOrigin, rayDir).x;
                float dstToSurface = min(sceneDepth, dstToOcean);

                float2 hitInfo             = raySphere(planetCentre, atmosphereRadius, rayOrigin, rayDir);
                float  dstToAtmosphere     = hitInfo.x;
                float  dstThroughAtmosphere = min(hitInfo.y, dstToSurface - dstToAtmosphere);

                float4 outputColor = originalCol;

                if (dstThroughAtmosphere > 0)
                {
                    const float epsilon      = 0.0001;
                    float3 pointInAtmosphere = rayOrigin + rayDir * (dstToAtmosphere + epsilon);
                    float3 light             = calculateLight(
                        pointInAtmosphere, rayDir,
                        dstThroughAtmosphere - epsilon * 2,
                        originalCol.rgb, uv);
                    outputColor = float4(light, 1);
                }

                surface.BaseColor = outputColor.rgb;
                surface.Alpha     = 1;
                return surface;
            }
            
            // --------------------------------------------------
            // Build Graph Inputs
            
            SurfaceDescriptionInputs BuildSurfaceDescriptionInputs(Varyings input)
            {
                SurfaceDescriptionInputs output;
                ZERO_INITIALIZE(SurfaceDescriptionInputs, output);
            
                float3 viewDirWS    = normalize(input.texCoord1.xyz);
                float  linearDepth  = LinearEyeDepth(
                    SHADERGRAPH_SAMPLE_SCENE_DEPTH(input.texCoord0.xy), _ZBufferParams);
                float3 cameraFwd    = -UNITY_MATRIX_V[2].xyz;
                float  camDistance  = linearDepth / dot(viewDirWS, cameraFwd);
                float3 positionWS   = viewDirWS * camDistance + GetCameraPositionWS();
            
                output.WorldSpacePosition = positionWS;
                output.ScreenPosition     = float4(input.texCoord0.xy, 0, 1);
                output.NDCPosition        = input.texCoord0.xy;
            
                return output;
            }
            
            #include "Packages/com.unity.shadergraph/Editor/Generation/Targets/Fullscreen/Includes/FullscreenCommon.hlsl"
            #include "Packages/com.unity.shadergraph/Editor/Generation/Targets/Fullscreen/Includes/FullscreenDrawProcedural.hlsl"
            
            ENDHLSL
        }
    }
}
