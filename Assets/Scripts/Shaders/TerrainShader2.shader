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

			//float4 triplanar(float3 vertPos, float3 normal, float scale)
			//{
			//	float2 uvX = vertPos.zy * scale;
			//	float2 uvY = vertPos.xz * scale;
			//	float2 uvZ = vertPos.xy * scale;
    		//
			//	float4 colX = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, uvX);
			//	float4 colY = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, uvY);
			//	float4 colZ = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, uvZ);
			//
			//	// Square normal to keep all values positive and sharpen the blend
			//	float3 blendWeight = normal * normal;
			//	// Normalise so x + y + z = 1
			//	blendWeight /= dot(blendWeight, 1);
			//
			//	return colX * blendWeight.x + colY * blendWeight.y + colZ * blendWeight.z;
			//}

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex);
                o.uv = v.uv;
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
				half4 texNoise = triplanar(i.vertex, i.normal, _NoiseScale, _NoiseTex, sampler_NoiseTex);
				half4 texNoise2 = triplanar(i.vertex, i.normal, _NoiseScale2, _NoiseTex, sampler_NoiseTex);

                return _ShoreLow;
            }
            ENDHLSL
        }
    }
}
