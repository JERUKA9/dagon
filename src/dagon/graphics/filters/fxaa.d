module dagon.graphics.filters.fxaa;

import dagon.core.ownership;
import dagon.graphics.postproc;
import dagon.graphics.framebuffer;

class PostFilterFXAA: PostFilter
{
    private string vs = q{
        #version 330 core
        
        uniform mat4 modelViewMatrix;
        uniform mat4 projectionMatrix;

        uniform vec2 viewSize;
        
        layout (location = 0) in vec2 va_Vertex;
        layout (location = 1) in vec2 va_Texcoord;

        out vec2 texCoord;
        
        void main()
        {
            texCoord = va_Texcoord;
            gl_Position = projectionMatrix * modelViewMatrix * vec4(va_Vertex * viewSize, 0.0, 1.0);
        }
    };

    private string fs = q{
        #version 330 core
        
        uniform sampler2D fbColor;
        uniform sampler2D fbDepth;
        uniform vec2 viewSize;
        
        in vec2 texCoord;
        out vec4 frag_color;

        const float FXAA_REDUCE_MIN = 1.0 / 128.0;
        const float FXAA_REDUCE_MUL = 1.0 / 8.0;
        const float FXAA_SPAN_MAX = 8.0;

        vec4 fxaa(sampler2D tex, vec2 fragCoord, vec2 resolution,
                   vec2 v_rgbNW, vec2 v_rgbNE, 
                   vec2 v_rgbSW, vec2 v_rgbSE, 
                   vec2 v_rgbM)
        {
            vec4 color;
            vec2 inverseVP = vec2(1.0 / resolution.x, 1.0 / resolution.y);
            vec3 rgbNW = texture(tex, v_rgbNW).xyz;
            vec3 rgbNE = texture(tex, v_rgbNE).xyz;
            vec3 rgbSW = texture(tex, v_rgbSW).xyz;
            vec3 rgbSE = texture(tex, v_rgbSE).xyz;
            vec4 texColor = texture(tex, v_rgbM);
            vec3 rgbM  = texColor.xyz;
            vec3 luma = vec3(0.299, 0.587, 0.114);
            float lumaNW = dot(rgbNW, luma);
            float lumaNE = dot(rgbNE, luma);
            float lumaSW = dot(rgbSW, luma);
            float lumaSE = dot(rgbSE, luma);
            float lumaM  = dot(rgbM,  luma);
            float lumaMin = min(lumaM, min(min(lumaNW, lumaNE), min(lumaSW, lumaSE)));
            float lumaMax = max(lumaM, max(max(lumaNW, lumaNE), max(lumaSW, lumaSE)));
            
            vec2 dir;
            dir.x = -((lumaNW + lumaNE) - (lumaSW + lumaSE));
            dir.y =  ((lumaNW + lumaSW) - (lumaNE + lumaSE));
            
            float dirReduce = max((lumaNW + lumaNE + lumaSW + lumaSE) *
                                  (0.25 * FXAA_REDUCE_MUL), FXAA_REDUCE_MIN);
            
            float rcpDirMin = 1.0 / (min(abs(dir.x), abs(dir.y)) + dirReduce);
            dir = min(vec2(FXAA_SPAN_MAX, FXAA_SPAN_MAX),
                      max(vec2(-FXAA_SPAN_MAX, -FXAA_SPAN_MAX),
                      dir * rcpDirMin)) * inverseVP;
            
            vec3 rgbA = 0.5 * (
                texture(tex, fragCoord * inverseVP + dir * (1.0 / 3.0 - 0.5)).xyz +
                texture(tex, fragCoord * inverseVP + dir * (2.0 / 3.0 - 0.5)).xyz);
            vec3 rgbB = rgbA * 0.5 + 0.25 * (
                texture(tex, fragCoord * inverseVP + dir * -0.5).xyz +
                texture(tex, fragCoord * inverseVP + dir * 0.5).xyz);

            float lumaB = dot(rgbB, luma);
            if ((lumaB < lumaMin) || (lumaB > lumaMax))
                color = vec4(rgbA, texColor.a);
            else
                color = vec4(rgbB, texColor.a);
            return color;
        }

        void main()
        {
            vec2 fragCoord = gl_FragCoord.xy;
            vec2 invScreenSize = 1.0 / viewSize;

            vec2 v_rgbNW = (fragCoord + vec2(-1.0, -1.0)) * invScreenSize;
            vec2 v_rgbNE = (fragCoord + vec2(1.0, -1.0)) * invScreenSize;
            vec2 v_rgbSW = (fragCoord + vec2(-1.0, 1.0)) * invScreenSize;
            vec2 v_rgbSE = (fragCoord + vec2(1.0, 1.0)) * invScreenSize;
            vec2 v_rgbM = vec2(fragCoord * invScreenSize);
            vec3 color = fxaa(fbColor, fragCoord, viewSize, v_rgbNW, v_rgbNE, v_rgbSW, v_rgbSE, v_rgbM).rgb; 
                    
            frag_color = vec4(color, 1.0); 
        }
    };

    override string vertexShader()
    {
        return vs;
    }

    override string fragmentShader()
    {
        return fs;
    }

    this(Framebuffer fb, Owner o)
    {
        super(fb, o);
    }
}
