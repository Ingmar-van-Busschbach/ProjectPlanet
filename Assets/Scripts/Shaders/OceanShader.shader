Shader "Lit/OceanShader"
{
    Properties
    {
		[Header(Flat Terrain)]
		_Color("Water Color", Color) = (0,0,0,1)
		_WaveColor("Wave Color", Color) = (1,1,1,1)

		[Header(Noise)]
		[NoScaleOffset] _NoiseTex("Noise Texture", 2D) = "white" {}
		_NoiseScale("Noise Scale", Float) = 1
		_NoiseScale2("Noise Scale2", Float) = 1
		_ScrollSpeedX("Scroll Speed X", Float) = 1
		_ScrollSpeedY("Scroll Speed Y", Float) = 1
		_ScrollSpeedZ("Scroll Speed Z", Float) = 1
		_WaveIntensity("Wave Intensity", Float) = 1
		_WaveHeightOffset("WaveHeightOffset", Float) = 1
		_VoronoiSpeed("Voronoi Speed", Float) = 1
		_VoronoiPower("Voronoi Power", Float) = 2
		_VoronoiDensity("Voronoi Density", Float) = 5
		_VoronoiDensity2("Voronoi Density 2", Float) = 10
		_VoronoiScale("Voronoi Scale", Float) = 10

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
			#include "../Includes/Noise.cginc"

			float bodyScale;

            struct appdata
            {
                float4 vertex : POSITION;
				float4 normal : NORMAL;
				float4 tangent : TANGENT;
				float2 UV : TEXCOORD0;
            };

            struct v2f
            {
                float4 vertexCS : SV_POSITION;
				float4 normal : NORMAL;
				float2 UV : TEXCOORD0;
				float3 vertexOS : TEXCOORD1;
				float3 vertexWS : TEXCOORD2;
				
            };

			// Other
			float _Glossiness, _Metallic, _Specular;
			TEXTURE2D(_NoiseTex);
			SAMPLER(sampler_NoiseTex);
			float4 _Color, _WaveColor;
			float _NoiseScale, _NoiseScale2;
			float _ScrollSpeedX, _ScrollSpeedY, _ScrollSpeedZ, _WaveIntensity, _WaveHeightOffset;
			float _VoronoiSpeed, _VoronoiDensity, _VoronoiPower, _VoronoiScale, _VoronoiDensity2;

			inline float2 unity_voronoi_noise_randomVector (float2 UV, float offset)
			{
			    float2x2 m = float2x2(15.27, 47.63, 99.41, 89.98);
			    UV = frac(sin(mul(UV, m)) * 46839.32);
			    return float2(sin(UV.y*+offset)*0.5+0.5, cos(UV.x*offset)*0.5+0.5);
			}

			float2 Unity_Voronoi_float(float2 UV, float AngleOffset, float CellDensity)
			{
				float Out;
				float Cells;
			    float2 g = floor(UV * CellDensity);
			    float2 f = frac(UV * CellDensity);
			    float t = 8.0;
			    float3 res = float3(8.0, 0.0, 0.0);
			
			    for(int y=-1; y<=1; y++)
			    {
			        for(int x=-1; x<=1; x++)
			        {
			            float2 lattice = float2(x,y);
			            float2 offset = unity_voronoi_noise_randomVector(lattice + g, AngleOffset);
			            float d = distance(lattice + offset, f);
			            if(d < res.x)
			            {
			                res = float3(d, offset.x, offset.y);
			                Out = res.x;
			                Cells = res.y;
			            }
			        }
			    }
				return float2(Out, Cells);
			}

            v2f vertex (appdata v)
            {
                v2f o;
				o.vertexOS = v.vertex.xyz;
				float3 bitangent = cross(v.normal, v.tangent.xyz);
				float3 v0 = o.vertexOS.xyz;
				float3 v1 = o.vertexOS + (v.tangent.xyz * 0.01);
				float3 v2 = o.vertexOS + (bitangent * 0.01);
				o.vertexWS = mul(UNITY_MATRIX_M, v.vertex);
				float3 offset = float3(_Time.y * _ScrollSpeedX, _Time.y * _ScrollSpeedY, _Time.y * _ScrollSpeedZ);
				float frequency = 5;
				float ns0 = _NoiseScale * snoise(float3(v0.x + offset.x, v0.y + offset.y, v0.z * offset.z) * frequency);
				v0.xyz += (((ns0+1)/2) * _WaveIntensity - _WaveHeightOffset) * v.normal;
				float ns1 = _NoiseScale * snoise(float3(v1.x + offset.x, v1.y + offset.y, v1.z * offset.z) * frequency);
				v1.xyz += (((ns1+1)/2) * _WaveIntensity - _WaveHeightOffset) * v.normal;
				float ns2 = _NoiseScale * snoise(float3(v2.x + offset.x, v2.y + offset.y, v2.z * offset.z) * frequency);
				v2.xyz += (((ns2+1)/2) * _WaveIntensity - _WaveHeightOffset) * v.normal;
				float3 vn = cross(v2-v0, v1-v0);
				o.normal = float4(normalize(-vn), 1);
				o.vertexCS = mul(UNITY_MATRIX_MVP, float4(v0, 1));
				o.UV = v.UV;
                return o;
            }

            half4 fragment (v2f i) : SV_Target
            {
				float2 voronoiOutput = Unity_Voronoi_float(i.UV * _VoronoiScale, _Time.y * _VoronoiSpeed, _VoronoiDensity);
				float2 voronoiOutput2 = Unity_Voronoi_float(i.UV * _VoronoiScale, _Time.y * _VoronoiSpeed, _VoronoiDensity2);
				float voronoiLayer = pow(voronoiOutput.x, _VoronoiPower);
				float voronoiLayer2 = pow(voronoiOutput2.x, _VoronoiPower);
				float voronoiResult = voronoiLayer * voronoiLayer2;
				float4 voronoiColor = lerp(_Color, _WaveColor, voronoiResult);

				InputData lighting = (InputData)0;
				lighting.positionWS = i.vertexWS;
				lighting.normalWS = normalize(mul(UNITY_MATRIX_M, float4(i.normal.xyz, 0)));
				lighting.viewDirectionWS = GetWorldSpaceViewDir(i.vertexWS);
				lighting.shadowCoord = TransformWorldToShadowCoord(i.vertexWS);

				SurfaceData surface = (SurfaceData) 0;
				surface.albedo = voronoiColor.xyz;
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
