Shader "Lit/OceanShader"
{
    Properties
    {
		[Header(Flat Terrain)]
		_Color("Water Color", Color) = (0,0,0,1)

		[Header(Noise)]
		[NoScaleOffset] _NoiseTex("Noise Texture", 2D) = "white" {}
		_NoiseScale("Noise Scale", Float) = 1
		_NoiseScale2("Noise Scale2", Float) = 1
		_ScrollSpeedX("Scroll Speed X", Float) = 1
		_ScrollSpeedY("Scroll Speed Y", Float) = 1
		_WaveIntensity("Wave Intensity", Float) = 1
		_WaveHeightOffset("WaveHeightOffset", Float) = 1

		[Header(Other)]
		_Specular("Specular", Range(0,1)) = 0.3
		_Glossiness("Smoothness", Range(0,1)) = 0.5
		_Metallic("Metallic", Range(0,1)) = 0.0
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

			// Other
			float _Glossiness, _Metallic, _Specular;
			TEXTURE2D(_NoiseTex);
			SAMPLER(sampler_NoiseTex);
			float4 _Color;
			float _NoiseScale, _NoiseScale2;
			float _ScrollSpeedX, _ScrollSpeedY, _WaveIntensity, _WaveHeightOffset;

			float4 triplanarOffset(float3 vertPos, float3 normal, float3 scale, Texture2D tex, SamplerState samplerTex, float2 offset)
			{
			    float3 scaledPos = vertPos / scale;
			
			    float4 colX = SAMPLE_TEXTURE2D_LOD(tex, samplerTex, scaledPos.zy + offset, 0);
			    float4 colY = SAMPLE_TEXTURE2D_LOD(tex, samplerTex, scaledPos.xz + offset, 0);
			    float4 colZ = SAMPLE_TEXTURE2D_LOD(tex, samplerTex, scaledPos.xy + offset, 0);
			
			    float3 blendWeight = normal * normal;
			    blendWeight /= dot(blendWeight, 1);
			
			    return colX * blendWeight.x + colY * blendWeight.y + colZ * blendWeight.z;
			}

            v2f vertex (appdata v)
            {
                v2f o;
				o.vertexOS = v.vertex.xyz;
				o.vertexWS = TransformObjectToWorld(v.vertex);
				o.normal = v.normal;
				// Sample noise texture at two different scales
				float2 offset = float2(_Time.y * _ScrollSpeedX, _Time.y * _ScrollSpeedY);
				float4 texNoise = triplanarOffset(o.vertexOS, o.normal, _NoiseScale, _NoiseTex, sampler_NoiseTex, offset);
				o.vertexCS = TransformObjectToHClip(v.vertex + (v.vertex * texNoise.x * _WaveIntensity) - (v.vertex * _WaveHeightOffset));

                return o;
            }

            half4 fragment (v2f i) : SV_Target
            {
				InputData lighting = (InputData)0;
				lighting.positionWS = i.vertexWS;
				lighting.normalWS = i.normal;
				lighting.viewDirectionWS = GetWorldSpaceViewDir(i.vertexWS);
				lighting.shadowCoord = TransformWorldToShadowCoord(i.vertexWS);

				SurfaceData surface = (SurfaceData) 0;
				surface.albedo = _Color.xyz;
				surface.alpha = _Color.w;
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
