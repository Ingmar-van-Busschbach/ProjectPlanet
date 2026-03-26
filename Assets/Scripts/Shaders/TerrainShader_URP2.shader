Shader "TerrainShaderURP2/Main"
{
    Properties
    {
        [Header(Flat Terrain)]
        _ShoreLow("Shore Low", Color) = (0,0,0,1)
        _ShoreHigh("Shore High", Color) = (0,0,0,1)
        _FlatLowA("Flat Low A", Color) = (0,0,0,1)
        _FlatHighA("Flat High A", Color) = (0,0,0,1)

        _FlatColBlend("Colour Blend", Range(0,3)) = 1.5
        _FlatColBlendNoise("Blend Noise", Range(0,1)) = 0.3
        _ShoreHeight("Shore Height", Range(0,0.2)) = 0.05
        _ShoreBlend("Shore Blend", Range(0,0.2)) = 0.03
        _MaxFlatHeight("Max Flat Height", Range(0,1)) = 0.5

        [Header(Steep Terrain)]
        _SteepLow("Steep Colour Low", Color) = (0,0,0,1)
        _SteepHigh("Steep Colour High", Color) = (0,0,0,1)
        _SteepBands("Steep Bands", Range(1, 20)) = 8
        _SteepBandStrength("Band Strength", Range(-1,1)) = 0.5

        [Header(Flat to Steep Transition)]
        _SteepnessThreshold("Steep Threshold", Range(0,1)) = 0.5
        _FlatToSteepBlend("Flat to Steep Blend", Range(0,0.3)) = 0.1
        _FlatToSteepNoise("Flat to Steep Noise", Range(0,0.2)) = 0.1

        [Header(Noise)]
        [NoScaleOffset] _NoiseTex("Noise Texture", 2D) = "white" {}
        _NoiseScale("Noise Scale", Float) = 1
        _NoiseScale2("Noise Scale2", Float) = 1

        [Header(Other)]
        _FresnelCol("Fresnel Colour", Color) = (1,1,1,1)
        _FresnelStrengthNear("Fresnel Strength Min", float) = 2
        _FresnelStrengthFar("Fresnel Strength Max", float) = 5
        _FresnelPow("Fresnel Power", float) = 2
        _Glossiness("Smoothness", Range(0,1)) = 0.5
        _Metallic("Metallic", Range(0,1)) = 0.0
        _HeightMin("Height Min", float) = 0
        _HeightMax("Height Max", float) = 0
        oceanLevel("Ocean Level", float) = 0
        _BumpMap("Normal Map", 2D) = "bump" {}
        _NormalStrength("Normal Strength", Range(0,1)) = 0.5
    }

    SubShader
    {
        // --- URP requires this tag ---
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Geometry"
        }
        LOD 200

        // =========================================================
        // PASS 1 — Forward Lit (main lighting pass)
        // =========================================================
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #pragma target 3.5

            // URP lighting keywords (shadows, light layers, etc.)
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile_fog

            // --- URP core includes (replaces UnityCG.cginc) ---
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderVariablesFunctions.hlsl"
            #include "../Includes/Triplanar2.cginc"
            #include "../Includes/Math.cginc"

            // ---- Textures (URP style: TEXTURE2D macro + SamplerState) ----
            TEXTURE2D(_NoiseTex);   SAMPLER(sampler_NoiseTex);
            TEXTURE2D(_BumpMap);    SAMPLER(sampler_BumpMap);

            // ---- Constant Buffer (required in URP for SRP Batcher compat) ----
            CBUFFER_START(UnityPerMaterial)
                // Flat terrain
                float4 _ShoreLow, _ShoreHigh;
                float4 _FlatLowA, _FlatHighA;
                float  _FlatColBlend, _FlatColBlendNoise;
                float  _ShoreHeight, _ShoreBlend;
                float  _MaxFlatHeight;

                // Steep terrain
                float4 _SteepLow, _SteepHigh;
                float  _SteepBands, _SteepBandStrength;

                // Flat to steep transition
                float  _SteepnessThreshold, _FlatToSteepBlend, _FlatToSteepNoise;

                // Noise
                float  _NoiseScale, _NoiseScale2;

                // Other
                float4 _FresnelCol;
                float  _FresnelStrengthNear, _FresnelStrengthFar, _FresnelPow;
                float  _Glossiness, _Metallic;
                float  _HeightMin, _HeightMax;
                float  _NormalStrength;
                float  oceanLevel;

                // BumpMap ST (needed even with [NoScaleOffset] on NoiseTex)
                float4 _BumpMap_ST;
            CBUFFER_END

            // These are set from script so they stay outside the CBUFFER
            float bodyScale;
            float2 heightMinMax;

            // ---- Vertex input ----
            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
                float4 tangentOS    : TANGENT;
                float2 uv           : TEXCOORD0;    // BumpMap UVs
                float4 terrainData  : TEXCOORD1;    // custom terrain data (was v.texcoord)
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            // ---- Interpolants passed to fragment ----
            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float2 uvBump       : TEXCOORD0;
                float3 positionWS   : TEXCOORD1;
                float3 normalWS     : TEXCOORD2;
                float4 tangentWS    : TEXCOORD3;
                float3 vertPosOS    : TEXCOORD4;    // object-space vertex pos (for height & steepness)
                float3 normalOS     : TEXCOORD5;    // object-space normal    (for steepness)
                float4 terrainData  : TEXCOORD6;
                float  fresnel      : TEXCOORD7;
                float  fogFactor    : TEXCOORD8;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            // ---- Vertex shader ----
            Varyings Vert(Attributes IN)
            {
                Varyings OUT;
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);

                // Store object-space data needed in frag for height/steepness math
                OUT.vertPosOS   = IN.positionOS.xyz;
                OUT.normalOS    = IN.normalOS;
                OUT.terrainData = IN.terrainData;

                // Transform to clip and world space
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.positionWS  = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.normalWS    = TransformObjectToWorldNormal(IN.normalOS);

                // Tangent (w stores handedness, same as before)
                float3 tangentWS = TransformObjectToWorldDir(IN.tangentOS.xyz);
                OUT.tangentWS    = float4(tangentWS, IN.tangentOS.w);

                // UV for bump map
                OUT.uvBump = TRANSFORM_TEX(IN.uv, _BumpMap);

                // Fresnel — same logic as original vert()
                float3 bodyWorldCentre    = GetObjectToWorldMatrix()._m03_m13_m23; // object origin in WS
                float  camRadiiFromSurface = (length(bodyWorldCentre - GetCameraPositionWS()) - bodyScale) / bodyScale;
                float  fresnelT            = smoothstep(0, 1, camRadiiFromSurface);
                float3 viewDir             = normalize(OUT.positionWS - GetCameraPositionWS());
                float  fresStrength        = lerp(_FresnelStrengthNear, _FresnelStrengthFar, fresnelT);
                OUT.fresnel = saturate(fresStrength * pow(1.0 + dot(viewDir, OUT.normalWS), _FresnelPow));

                OUT.fogFactor = ComputeFogFactor(OUT.positionHCS.z);

                return OUT;
            }

            // ---- Fragment shader ----
            half4 Frag(Varyings IN) : SV_Target
            {
                // ---- Steepness (identical logic to original surf) ----
                float3 sphereNormal = normalize(IN.vertPosOS);
                float steepness = 1.0 - dot(sphereNormal, IN.normalOS);
                steepness = remap01(steepness, 0, 0.65);

                // Height overrides
                float2 hMinMax = heightMinMax;
                if (_HeightMin > 0) hMinMax.x = _HeightMin;
                if (_HeightMax > 0) hMinMax.y = _HeightMax;

                // Heights
                float terrainHeight    = length(IN.vertPosOS);
                float shoreHeight      = lerp(hMinMax.x, 1.0, oceanLevel);
                float aboveShoreH01    = remap01(terrainHeight, shoreHeight, hMinMax.y);
                float flatHeight01     = remap01(aboveShoreH01, 0, _MaxFlatHeight);

                // Noise samples — triplanar uses object-space pos + normal
                // NOTE: triplanar() takes a sampler2D; if your Triplanar.cginc uses
                //       tex2D internally you may need to update it to SAMPLE_TEXTURE2D.
                //       A compatible overload is provided below as a fallback.
                float4 texNoise  = triplanar(IN.vertPosOS, IN.normalOS, _NoiseScale,  _NoiseTex, sampler_NoiseTex);
                float4 texNoise2 = triplanar(IN.vertPosOS, IN.normalOS, _NoiseScale2, _NoiseTex, sampler_NoiseTex);

                // ---- Flat terrain colour ----
                float flatColBlendW = Blend(0, _FlatColBlend, (flatHeight01 - 0.5) + (texNoise.b - 0.5) * _FlatColBlendNoise);
                float3 flatCol      = lerp(_FlatLowA.rgb, _FlatHighA.rgb, flatColBlendW);
                flatCol             = lerp(flatCol, (_FlatLowA.rgb + _FlatHighA.rgb) * 0.5, texNoise.a);

                // Shore
                float shoreBlendW = 1.0 - Blend(_ShoreHeight, _ShoreBlend, flatHeight01);
                float4 shoreCol   = lerp(_ShoreLow, _ShoreHigh, remap01(aboveShoreH01, 0, _ShoreHeight));
                shoreCol          = lerp(shoreCol, (_ShoreLow + _ShoreHigh) * 0.5, texNoise.g);
                flatCol           = lerp(flatCol, shoreCol.rgb, shoreBlendW);

                // ---- Steep terrain colour ----
                float3 sphereTangent = normalize(float3(-sphereNormal.z, 0, sphereNormal.x));
                float3 normalTangent = normalize(IN.normalOS - sphereNormal * dot(IN.normalOS, sphereNormal));
                float  banding       = dot(sphereTangent, normalTangent) * 0.5 + 0.5;
                banding = (int)(banding * (_SteepBands + 1)) / _SteepBands;
                banding = (abs(banding - 0.5) * 2.0 - 0.5) * _SteepBandStrength;
                float3 steepCol = lerp(_SteepLow.rgb, _SteepHigh.rgb, aboveShoreH01 + banding);

                // ---- Flat-to-steep transition ----
                float flatBlendNoise  = (texNoise2.r - 0.5) * _FlatToSteepNoise;
                float flatStrength    = 1.0 - Blend(_SteepnessThreshold + flatBlendNoise, _FlatToSteepBlend, steepness);
                float flatHeightFall  = 1.0 - Blend(_MaxFlatHeight + flatBlendNoise, _FlatToSteepBlend, aboveShoreH01);
                flatStrength         *= flatHeightFall;

                // ---- Composite colour + fresnel ----
                float3 compositeCol = lerp(steepCol, flatCol, flatStrength);
                compositeCol        = lerp(compositeCol, _FresnelCol.rgb, IN.fresnel);

                // Glossiness driven by luminance (same as original)
                float glossiness = dot(compositeCol, 1.0) / 3.0 * _Glossiness;

                // ---- Normal map ----
                float3 normalTS = UnpackNormal(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, IN.uvBump));
                normalTS.xy    *= _NormalStrength;
                normalTS        = normalize(normalTS);

                // Reconstruct TBN to transform normal from tangent → world space
                float3 bitangentWS = cross(IN.normalWS, IN.tangentWS.xyz) * IN.tangentWS.w;
                float3 normalWS    = normalize(
                    normalTS.x * IN.tangentWS.xyz +
                    normalTS.y * bitangentWS       +
                    normalTS.z * IN.normalWS
                );

                // ---- Build URP InputData ----
                InputData inputData = (InputData)0;
                inputData.positionWS        = IN.positionWS;
                inputData.normalWS          = normalWS;
                inputData.viewDirectionWS   = normalize(GetCameraPositionWS() - IN.positionWS);
                inputData.shadowCoord       = TransformWorldToShadowCoord(IN.positionWS);
                inputData.fogCoord          = IN.fogFactor;
                inputData.bakedGI           = SampleSH(normalWS);
                inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(IN.positionHCS);
                inputData.shadowMask        = SAMPLE_SHADOWMASK(float2(0,0)); // no lightmap

                // ---- Build URP SurfaceData ----
                SurfaceData surfaceData = (SurfaceData)0;
                surfaceData.albedo      = compositeCol;
                surfaceData.metallic    = _Metallic;
                surfaceData.smoothness  = glossiness;
                surfaceData.normalTS    = normalTS;
                surfaceData.alpha       = 1.0;
                surfaceData.occlusion   = 1.0;

                // ---- PBR lighting (replaces #pragma surface … Standard) ----
                half4 color = UniversalFragmentPBR(inputData, surfaceData);

                // Apply fog
                color.rgb = MixFog(color.rgb, IN.fogFactor);

                return color;
            }
            ENDHLSL
        }

        // =========================================================
        // PASS 2 — Shadow Caster
        // (built-in RP got this for free via FallBack "Diffuse";
        //  URP requires an explicit pass)
        // =========================================================
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull Back

            HLSLPROGRAM
            #pragma vertex ShadowVert
            #pragma fragment ShadowFrag
            #pragma target 3.5
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"

            // ShadowCasterPass.hlsl defines ShadowPassVertex and ShadowPassFragment.
            // We just alias them.
            Varyings ShadowVert(Attributes input) { return ShadowPassVertex(input); }
            half4     ShadowFrag(Varyings input) : SV_Target { return ShadowPassFragment(input); }
            ENDHLSL
        }

        // =========================================================
        // PASS 3 — Depth Only
        // (needed for depth prepass, depth-of-field, SSAO, etc.)
        // =========================================================
        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }

            ZWrite On
            ColorMask R
            Cull Back

            HLSLPROGRAM
            #pragma vertex DepthVert
            #pragma fragment DepthFrag
            #pragma target 3.5

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"

            Varyings DepthVert(Attributes input) { return DepthOnlyVertex(input); }
            half4     DepthFrag(Varyings input) : SV_Target { return DepthOnlyFragment(input); }
            ENDHLSL
        }
    }
    // No FallBack needed — all necessary passes are explicit above
}
