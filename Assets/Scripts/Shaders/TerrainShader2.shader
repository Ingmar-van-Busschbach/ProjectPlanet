Shader "Unlit/TerrainShader2"
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
        Tags { "RenderType"="Opaque" "RenderPipeline" = "UniversalPipeline" }
        LOD 100

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "../Includes/Math.cginc"
			#include "../Includes/Triplanar2.cginc"

			//Fresnel Data
			float4 _FresnelCol;
			float _FresnelStrengthNear, _FresnelStrengthFar, _FresnelPow;
			float bodyScale;

			struct Input
			{
				float2 uv_MainTex;
				float2 uv_BumpMap;
				float3 worldPos;
				float4 terrainData;
				float3 vertPos;
				float3 normal;
				float4 tangent;
				float fresnel;
			};

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
				float4 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
				float4 normal : NORMAL;
				//float2 uv_MainTex;
				//float2 uv_BumpMap;
				//float3 worldPos;
				//float4 terrainData;
				//float3 vertPos;
				//float3 normal;
				//float4 tangent;
				//float fresnel;
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
			float _Glossiness, _Metallic;
			TEXTURE2D(_NoiseTex);
			SAMPLER(sampler_NoiseTex);
			float _NoiseScale, _NoiseScale2;
			float _HeightMin, _HeightMax;
			float _NormalStrength;

			// Height data
			float2 heightMinMax;
			float oceanLevel;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex);
                o.uv = v.uv;
				o.normal = v.normal;
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
				// Calculate steepness: 0 where totally flat, 1 at max steepness
				float3 sphereNormal = normalize(i.vertex);
				float steepness = 1 - dot(sphereNormal, i.normal);
				steepness = remap01(steepness, 0, 0.65);

				//Overrides in case the material instance has to be saved to disk
				if (_HeightMin > 0) { heightMinMax.x = _HeightMin;}
				if (_HeightMax > 0) { heightMinMax.y = _HeightMax;}

				// Calculate heights
				float terrainHeight = length(i.vertex);
				float shoreHeight = lerp(heightMinMax.x, 1, oceanLevel);
				float aboveShoreHeight01 = remap01(terrainHeight, shoreHeight, heightMinMax.y);
				float flatHeight01 = remap01(aboveShoreHeight01, 0, _MaxFlatHeight);

				// Sample noise texture at two different scales
				float4 texNoise = triplanar(i.vertex, i.normal, _NoiseScale, _NoiseTex, sampler_NoiseTex);
				float4 texNoise2 = triplanar(i.vertex, i.normal, _NoiseScale2, _NoiseTex, sampler_NoiseTex);

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

                return float4(compositeCol.xyz,1);
            }
            ENDHLSL
        }
    }
}
