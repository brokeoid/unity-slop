Shader "Custom/HDRP_VertexAnimation"
{
    Properties
    {
        _BaseColor("Base Color", Color) = (0.8, 0.8, 0.8, 1)
        _AnimationTexture("Animation Texture", 2D) = "white" {}
        _AnimationTime("Animation Time", Range(0,1)) = 0
        _IsWalking("Is Walking", Range(0,1)) = 0
        _FrameCount("Frame Count", Int) = 16
        _VertexCount("Vertex Count", Int) = 1000
        _TextureWidth("Texture Width", Int) = 512
        
        [HideInInspector] _Surface("__surface", Float) = 0.0
        [HideInInspector] _BlendMode("__blendmode", Float) = 0.0
        [HideInInspector] _AlphaCutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5
        [HideInInspector] _ZWrite("__zw", Float) = 1.0
        [HideInInspector] _CullMode("__cullmode", Float) = 2.0
    }

    HLSLINCLUDE
    #pragma target 4.5
    #pragma only_renderers d3d11 playstation xboxone xboxseries vulkan metal switch
    #pragma multi_compile_instancing
    #pragma multi_compile _ DOTS_INSTANCING_ON
    ENDHLSL

    SubShader
    {
        Tags 
        { 
            "RenderPipeline" = "HDRenderPipeline"
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
        }

        Pass
        {
            Name "Forward"
            Tags { "LightMode" = "Forward" }

            Blend One Zero
            ZWrite On
            Cull Back

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderVariables.hlsl"
            
            TEXTURE2D(_AnimationTexture);
            SAMPLER(sampler_AnimationTexture);
            
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float _AnimationTime;
                float _IsWalking;
                int _FrameCount;
                int _VertexCount;
                int _TextureWidth;
            CBUFFER_END
            
            struct Attributes
            {
                float3 positionOS : POSITION;
                float3 normalOS : NORMAL;
                uint vertexID : SV_VertexID;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 normalWS : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            
            Varyings Vert(Attributes input)
            {
                Varyings output;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                
                float3 positionOS = input.positionOS;
                
                // Apply vertex animation if walking
                if (_IsWalking > 0.5)
                {
                    float frame = _AnimationTime * (_FrameCount - 1);
                    int frameA = (int)floor(frame);
                    int frameB = min(frameA + 1, _FrameCount - 1);
                    float frameLerp = frac(frame);
                    
                    // Calculate texture coordinates
                    int pixelsPerFrame = _VertexCount;
                    int heightPerFrame = (_VertexCount + _TextureWidth - 1) / _TextureWidth;
                    
                    int vertexIndex = input.vertexID;
                    int pixelX = vertexIndex % _TextureWidth;
                    int pixelYOffset = vertexIndex / _TextureWidth;
                    
                    float u = (pixelX + 0.5) / (float)_TextureWidth;
                    float vA = (frameA * heightPerFrame + pixelYOffset + 0.5) / (float)(_FrameCount * heightPerFrame);
                    float vB = (frameB * heightPerFrame + pixelYOffset + 0.5) / (float)(_FrameCount * heightPerFrame);
                    
                    // Sample animation texture
                    float3 offsetA = SAMPLE_TEXTURE2D_LOD(_AnimationTexture, sampler_AnimationTexture, float2(u, vA), 0).xyz;
                    float3 offsetB = SAMPLE_TEXTURE2D_LOD(_AnimationTexture, sampler_AnimationTexture, float2(u, vB), 0).xyz;
                    
                    float3 offset = lerp(offsetA, offsetB, frameLerp);
                    positionOS += offset;
                }
                
                // Transform to world and clip space
                float3 positionWS = TransformObjectToWorld(positionOS);
                output.positionCS = TransformWorldToHClip(positionWS);
                output.positionWS = positionWS;
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                
                return output;
            }
            
            float4 Frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                
                // Simple lighting
                float3 lightDir = normalize(float3(0.5, 1.0, 0.3));
                float3 normalWS = normalize(input.normalWS);
                float ndotl = saturate(dot(normalWS, lightDir));
                
                float3 ambient = float3(0.3, 0.3, 0.35);
                float3 diffuse = _BaseColor.rgb * ndotl;
                
                return float4(ambient + diffuse, 1.0);
            }
            
            ENDHLSL
        }
        
        // Shadow caster pass
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
            
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderVariables.hlsl"
            
            TEXTURE2D(_AnimationTexture);
            SAMPLER(sampler_AnimationTexture);
            
            CBUFFER_START(UnityPerMaterial)
                float _AnimationTime;
                float _IsWalking;
                int _FrameCount;
                int _VertexCount;
                int _TextureWidth;
            CBUFFER_END
            
            struct Attributes
            {
                float3 positionOS : POSITION;
                uint vertexID : SV_VertexID;
            };
            
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
            };
            
            Varyings ShadowVert(Attributes input)
            {
                Varyings output;
                float3 positionOS = input.positionOS;
                
                // Same vertex animation as forward pass
                if (_IsWalking > 0.5)
                {
                    float frame = _AnimationTime * (_FrameCount - 1);
                    int frameA = (int)floor(frame);
                    int frameB = min(frameA + 1, _FrameCount - 1);
                    float frameLerp = frac(frame);
                    
                    int heightPerFrame = (_VertexCount + _TextureWidth - 1) / _TextureWidth;
                    int vertexIndex = input.vertexID;
                    int pixelX = vertexIndex % _TextureWidth;
                    int pixelYOffset = vertexIndex / _TextureWidth;
                    
                    float u = (pixelX + 0.5) / (float)_TextureWidth;
                    float vA = (frameA * heightPerFrame + pixelYOffset + 0.5) / (float)(_FrameCount * heightPerFrame);
                    float vB = (frameB * heightPerFrame + pixelYOffset + 0.5) / (float)(_FrameCount * heightPerFrame);
                    
                    float3 offsetA = SAMPLE_TEXTURE2D_LOD(_AnimationTexture, sampler_AnimationTexture, float2(u, vA), 0).xyz;
                    float3 offsetB = SAMPLE_TEXTURE2D_LOD(_AnimationTexture, sampler_AnimationTexture, float2(u, vB), 0).xyz;
                    
                    float3 offset = lerp(offsetA, offsetB, frameLerp);
                    positionOS += offset;
                }
                
                output.positionCS = TransformWorldToHClip(TransformObjectToWorld(positionOS));
                return output;
            }
            
            float4 ShadowFrag(Varyings input) : SV_Target
            {
                return 0;
            }
            
            ENDHLSL
        }
    }
    
    FallBack "Hidden/HDRP/FallbackError"
}
