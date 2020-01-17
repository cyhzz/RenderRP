// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'

Shader "Custm/Water"
{
    Properties
    {
        //_Color ("Color", Color) = (1,1,1,1)
        //_MainTex ("Albedo (RGB)", 2D) = "white" {}
		_Glossiness("Smoothness", Range(0,1)) = 0.5
		_Metallic("Metallic", Range(0,1)) = 0.0
		_WaterA("WaterA",Color) = (1,1,1,1)
		_WaterB("WaterB", Color) = (1,1,1,1)
		_DepthMax("DepthMax", float) = 1

		_NormalTex("Normal",2D) = "white"{}
		_NormalTile("Normal Tile" ,float) = 1
		_NormalStrength("NormalStrength",float) = 1
		_NormalSpeed("NormalSpeed",Vector) = (1,1,1,1)

		_NoiseTile("NoiseTile",Vector) = (1,1,1,1)
		_WaveTile("WaveTile",float) = 1
		_WaveScale("WaveScale", float) = 1
		_WaveSpeed("WaveSpeed", float) = 1
		_WaveStrength("WaveStrength", float) = 1

		_NoiseCutoff("NoiseCutoff", Range(0,1)) = 1
		_NoiseSpeed("NoiseSpeed",Vector) = (0,0,0,0)

		_FoamMaxDistance("FoamMaxDistance",float) = 1
		_FoamMinDistance("FoamMinDistance",float) = 1
		_FoamStrength("FoamStrength",float) = 1
		_FoamColor("FoamColor", Color) = (1,1,1,1)
		
		_SurfaceDistortion("SurfaceDistortion",2D) = "white"{}
		_SurfaceDistortionAmount("SurfaceDistortion Amount",float) = 0

    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue" = "Transparent"}
		Blend SrcAlpha OneMinusSrcAlpha
		ZWrite Off
		LOD 200
        CGPROGRAM
		#define SMOOTHSTEP_AA 0.01

        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf Standard fullforwardshadows vertex:vert alpha

        // Use shader model 3.0 target, to get nicer looking lighting
        #pragma target 3.0

        //sampler2D _MainTex;
		half4 _WaterA;
		half4 _WaterB;
		float _DepthMax;

		sampler2D _NormalTex;
		float _NormalTile;
		float _NormalStrength;
		float2 _NormalSpeed;

		float2 _NoiseTile;
		float _WaveTile;
		float _WaveScale;
		float _WaveSpeed;
		float _WaveStrength;

		float _NoiseCutoff;
		float2 _NoiseSpeed;

		sampler2D _CameraDepthTexture;
		float _FoamMaxDistance;
		float _FoamMinDistance;
		float _FoamStrength;
		float4 _FoamColor;

		sampler2D _SurfaceDistortion;
		float _SurfaceDistortionAmount;
		float4 _SurfaceDistortion_ST;

		sampler2D _CameraNormalsTexture;

        struct Input
        {
			float3 worldNormal;
			float3 viewDir;
			float3 worldPos;
			float noiseValue;
			float4 screenPos;

			float2 distortUV;
			
			float3 viewNormal;
			INTERNAL_DATA
        };

        half _Glossiness;
        half _Metallic;
        fixed4 _Color;

        // Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
        // See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
        // #pragma instancing_options assumeuniformscaling
        UNITY_INSTANCING_BUFFER_START(Props)
            // put more per-instance properties here
        UNITY_INSTANCING_BUFFER_END(Props)

		inline float unity_noise_interpolate(float a, float b, float t)
		{
			return (1.0 - t)*a + (t*b);
		}

		inline float unity_noise_randomValue(float2 uv)
		{
			return frac(sin(dot(uv, float2(12.9898, 78.233)))*43758.5453);
		}

		inline float unity_valueNoise(float2 uv)
		{
			float2 i = floor(uv);
			float2 f = frac(uv);
			f = f * f * (3.0 - 2.0 * f);
			uv = abs(frac(uv) - 0.5);
			float2 c0 = i + float2(0.0, 0.0);
			float2 c1 = i + float2(1.0, 0.0);
			float2 c2 = i + float2(0.0, 1.0);
			float2 c3 = i + float2(1.0, 1.0);
			float r0 = unity_noise_randomValue(c0);
			float r1 = unity_noise_randomValue(c1);
			float r2 = unity_noise_randomValue(c2);
			float r3 = unity_noise_randomValue(c3);
			float bottomOfGrid = unity_noise_interpolate(r0, r1, f.x);
			float topOfGrid = unity_noise_interpolate(r2, r3, f.x);
			float t = unity_noise_interpolate(bottomOfGrid, topOfGrid, f.y);
			return t;
		}

		void Unity_SimpleNoise_float(float2 UV, float Scale, out float Out)
		{
			float t = 0.0;

			float freq = pow(2.0, float(0));
			float amp = pow(0.5, float(3 - 0));
			t += unity_valueNoise(float2(UV.x*Scale / freq, UV.y*Scale / freq))*amp;

			freq = pow(2.0, float(1));
			amp = pow(0.5, float(3 - 1));
			t += unity_valueNoise(float2(UV.x*Scale / freq, UV.y*Scale / freq))*amp;

			freq = pow(2.0, float(2));
			amp = pow(0.5, float(3 - 2));
			t += unity_valueNoise(float2(UV.x*Scale / freq, UV.y*Scale / freq))*amp;

			Out = t;
		}
		float4 alphaBlend(float4 top, float4 bottom)
		{
			float3 color = (top.rgb * top.a) + (bottom.rgb * (1 - top.a));
			float alpha = top.a + bottom.a * (1 - top.a);

			return float4(color, alpha);
		}
		void vert(inout appdata_full v,out Input o)
		{
			UNITY_INITIALIZE_OUTPUT(Input, o);
			
			float4 world_space_vertex = mul(unity_ObjectToWorld,v.vertex);
			float2 noiseUV = world_space_vertex.xz*_NoiseTile*_WaveTile;
			noiseUV.x += _Time.x * 1 * _WaveSpeed;
			float noiseValue = 0;
			Unity_SimpleNoise_float(noiseUV, _WaveScale, noiseValue);
			//noiseValue = clamp(noiseValue, 0.2, 1.0);
			world_space_vertex.y += noiseValue * _WaveStrength;
			v.vertex = mul(unity_WorldToObject,world_space_vertex);
			o.distortUV = TRANSFORM_TEX(v.texcoord, _SurfaceDistortion);
			o.viewNormal = COMPUTE_VIEW_NORMAL;
		}

        void surf (Input IN, inout SurfaceOutputStandard o)
        {

			float2 normalUV = IN.worldPos.xz;
			normalUV *= _NormalTile;
			normalUV.x += _Time.x*-1 * _NormalSpeed.x;
			normalUV.y += _Time.x * -0.3* _NormalSpeed.y;
			fixed3 normalOne = UnpackNormal(tex2D(_NormalTex, normalUV));

			float2 normalUVTwo = IN.worldPos.xz;
			normalUVTwo *= _NormalTile * 2;
			normalUVTwo.x += _Time.x * 1 * _NormalSpeed.x;
			normalUVTwo.y += _Time.x * 0.3* _NormalSpeed.y;
			fixed3 normalTwo = UnpackNormal(tex2D(_NormalTex, normalUVTwo));
			
			normalOne.xy *= _NormalStrength;
			normalTwo.xy *= _NormalStrength;

			fixed3 normalFinal = normalize(fixed3(normalOne.rg+ normalTwo.rg, normalOne.b*normalTwo.b));

			o.Normal = normalFinal;

			float2 distortSample = (tex2D(_SurfaceDistortion, IN.distortUV).xy*2-1)*_SurfaceDistortionAmount;

			float2 noiseUV = IN.worldPos.xz*_NoiseTile*_WaveTile + distortSample;
			noiseUV.x += _Time.y * 1 * _NoiseSpeed.x;
			noiseUV.y += _Time.y * 1 * _NoiseSpeed.y;

			float noiseValue = 0;
			Unity_SimpleNoise_float(noiseUV, _WaveScale, noiseValue);
			noiseValue =clamp(noiseValue, 0.6,1.0);

			float existingDepth01 = tex2Dproj(_CameraDepthTexture, UNITY_PROJ_COORD(IN.screenPos)).r;
			float existingDepthLinear = LinearEyeDepth(existingDepth01);
			float depthDifference = existingDepthLinear - IN.screenPos.w;
			float depthDiff01 = saturate(depthDifference/_DepthMax);
			float4 waterColor = lerp(_WaterA,_WaterB,depthDiff01);

			float3 normalBuffer = tex2Dproj(_CameraNormalsTexture, UNITY_PROJ_COORD(IN.screenPos));
			float3 normalDot = saturate(dot(normalBuffer, IN.viewNormal));

			float foamDistance = lerp(_FoamMaxDistance,_FoamMinDistance, normalDot);
			float foamDepthDiff01 = saturate(depthDifference/ foamDistance);
			float surfaceNoiseCutoff = foamDepthDiff01 * _NoiseCutoff;
			//float surfaceNoise = noiseValue > surfaceNoiseCutoff ? 1 : 0;
			float surfaceNoise = smoothstep(surfaceNoiseCutoff - SMOOTHSTEP_AA, surfaceNoiseCutoff + SMOOTHSTEP_AA, noiseValue);
			float4 surfaceNoiseColor = _FoamColor;
			surfaceNoiseColor.a *= surfaceNoise;

			o.Albedo =alphaBlend(surfaceNoiseColor,waterColor);
            o.Metallic = _Metallic;
            o.Smoothness = _Glossiness;
            o.Alpha = waterColor.a;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
