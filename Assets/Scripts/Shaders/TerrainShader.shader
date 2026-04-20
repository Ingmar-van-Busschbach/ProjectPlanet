Shader "Lit/TerrainShader"
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
		_Specular("Specular", Range(0,1)) = 0.3
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
        Tags
		{
			"RenderType"="Opaque"
			"RenderPipeline" = "UniversalPipeline"
			"Queue" = "Geometry"
		}
        LOD 200

        Pass
        {
			Name "ForwardLit"
			Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
			#define _SPECULAR_COLOR
            #pragma vertex vertex
            #pragma fragment fragment
			#pragma shader_feature _FORWARD_PLUS
			#pragma shader_feature_fragment _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
			#pragma shader_feature_fragment _ADDITIONAL_LIGHT_SHADOWS

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "../Includes/Math.cginc"
			#include "../Includes/Triplanar2.cginc"

			//Fresnel Data
			float4 _FresnelCol;
			float _FresnelStrengthNear, _FresnelStrengthFar, _FresnelPow;
			float bodyScale;

            struct appdata
            {
                float4 vertex : POSITION;
				float4 normal : NORMAL;
            };

            struct v2f
            {
                float4 vertexCS : SV_POSITION;
				float4 normal : NORMAL;
				float3 vertexOS : TEXCOORD1;
				float3 vertexWS : TEXCOORD2;
            };

            // Flat terrain
			float4 _ShoreLow, _ShoreHigh;
			float4 _FlatLowA, _FlatHighA;
			float _FlatColBlend, _FlatColBlendNoise;
			float _ShoreHeight, _ShoreBlend;
			float _MaxFlatHeight;

			// Steep terrain
			float4 _SteepLow, _SteepHigh;
			float _SteepBands, _SteepBandStrength;

			// Flat to steep transition
			float _SteepnessThreshold, _FlatToSteepBlend, _FlatToSteepNoise;

			// Other
			float _Glossiness, _Metallic, _Specular;
			TEXTURE2D(_NoiseTex);
			SAMPLER(sampler_NoiseTex);
			float _NoiseScale, _NoiseScale2;
			float _HeightMin, _HeightMax;
			float _NormalStrength;

			// Height data
			float2 heightMinMax;
			float oceanLevel;

            v2f vertex (appdata v)
            {
                v2f o;
				o.vertexOS = v.vertex.xyz;
				o.vertexWS = TransformObjectToWorld(v.vertex);
                o.vertexCS = TransformObjectToHClip(v.vertex);
				o.normal = v.normal;
                return o;
            }

            half4 fragment (v2f i) : SV_Target
            {
				// Calculate steepness: 0 where totally flat, 1 at max steepness
				float3 sphereNormal = normalize(i.vertexOS);
				float steepness = 1 - dot(sphereNormal, i.normal);
				steepness = remap01(steepness, 0, 0.65);

				//Overrides in case the material instance has to be saved to disk
				if (_HeightMin > 0) { heightMinMax.x = _HeightMin;}
				if (_HeightMax > 0) { heightMinMax.y = _HeightMax;}

				// Calculate heights
				float terrainHeight = length(i.vertexOS);
				float shoreHeight = lerp(heightMinMax.x, 1, oceanLevel);
				float aboveShoreHeight01 = remap01(terrainHeight, shoreHeight, heightMinMax.y);
				float flatHeight01 = remap01(aboveShoreHeight01, 0, _MaxFlatHeight);

				// Sample noise texture at two different scales
				float4 texNoise = triplanar(i.vertexOS, i.normal, _NoiseScale, _NoiseTex, sampler_NoiseTex);
				float4 texNoise2 = triplanar(i.vertexOS, i.normal, _NoiseScale2, _NoiseTex, sampler_NoiseTex);

				// Flat terrain colour
				float flatColBlendWeight = Blend(0, _FlatColBlend, (flatHeight01 - .5) + (texNoise.b - 0.5) * _FlatColBlendNoise);
				float3 flatTerrainCol = lerp(_FlatLowA, _FlatHighA, flatColBlendWeight);
				flatTerrainCol = lerp(flatTerrainCol, (_FlatLowA + _FlatHighA) / 2, texNoise.a);

				// Shore
				float shoreBlendWeight = 1 - Blend(_ShoreHeight, _ShoreBlend, flatHeight01);
				float4 shoreCol = lerp(_ShoreLow, _ShoreHigh, remap01(aboveShoreHeight01, 0, _ShoreHeight));
				shoreCol = lerp(shoreCol, (_ShoreLow + _ShoreHigh) / 2, texNoise.g);
				flatTerrainCol = lerp(flatTerrainCol, shoreCol, shoreBlendWeight);

				// Steep terrain colour
				float3 sphereTangent = normalize(float3(-sphereNormal.z, 0, sphereNormal.x));
				float3 normalTangent = normalize(i.normal - sphereNormal * dot(i.normal, sphereNormal));
				float banding = dot(sphereTangent, normalTangent) * .5 + .5;
				banding = (int)(banding * (_SteepBands + 1)) / _SteepBands;
				banding = (abs(banding - 0.5) * 2 - 0.5) * _SteepBandStrength;
				float3 steepTerrainCol = lerp(_SteepLow, _SteepHigh, aboveShoreHeight01 + banding);

				// Flat to steep colour transition
				float flatBlendNoise = (texNoise2.r - 0.5) * _FlatToSteepNoise;
				float flatStrength = 1 - Blend(_SteepnessThreshold + flatBlendNoise, _FlatToSteepBlend, steepness);
				float flatHeightFalloff = 1 - Blend(_MaxFlatHeight + flatBlendNoise, _FlatToSteepBlend, aboveShoreHeight01);
				flatStrength *= flatHeightFalloff;

				// Set surface colour
				float3 compositeCol = lerp(steepTerrainCol, flatTerrainCol, flatStrength);

                //return float4(compositeCol.xyz,1);
				//return float4(i.normal.xyz, 1);
				//return float4(i.uv.x, i.uv.y, 0, 1);

				InputData lighting = (InputData)0;
				lighting.positionWS = i.vertexWS;
				lighting.normalWS = i.normal;
				lighting.viewDirectionWS = GetWorldSpaceViewDir(i.vertexWS);
				lighting.shadowCoord = TransformWorldToShadowCoord(i.vertexWS);

				SurfaceData surface = (SurfaceData) 0;
				surface.albedo = compositeCol.xyz;
				surface.alpha = 1;
				surface.smoothness = _Glossiness;
				surface.specular = _Specular;
				surface.metallic = _Metallic;
				return UniversalFragmentBlinnPhong(lighting, surface) + unity_AmbientSky;
            }
            ENDHLSL
        }

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
		
		    #pragma multi_compile_shadowcaster
		    #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
		
		    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
		    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
		
		    struct ShadowAppdata
		    {
		        float4 vertex   : POSITION;
		        float3 normal   : NORMAL;
		    };
		
		    struct ShadowV2F
		    {
		        float4 pos : SV_POSITION;
				float4 shadowCoords : TEXCOORD3;
		    };
		
		    ShadowV2F ShadowVert(ShadowAppdata v)
		    {
		        ShadowV2F o;
		        o.pos = TransformObjectToHClip(v.vertex.xyz);
				VertexPositionInputs positions = GetVertexPositionInputs(v.vertex.xyz);
				o.shadowCoords = GetShadowCoord(positions);
		        return o;
		    }
		
		    half4 ShadowFrag(ShadowV2F i) : SV_Target
		    {
                half shadowAmount = MainLightRealtimeShadow(i.shadowCoords);
                return shadowAmount;
		    }
		
		    ENDHLSL
		}
    }
}
