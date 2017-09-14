module dagon.graphics.filters.lens;

import dagon.core.ownership;
import dagon.graphics.postproc;
import dagon.graphics.framebuffer;

class PostFilterLensDistortion: PostFilter
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

        const float k = 0.1;
        const float kcube = 0.1;
        const float scale = 0.84;
        const float dispersion = 0.01;

        void main()
        {
            vec3 eta = vec3(1.0 + dispersion * 0.9, 1.0 + dispersion * 0.6, 1.0 + dispersion * 0.3);
            vec2 texcoord = texCoord;
            vec2 cancoord = texCoord;
            float r2 = (cancoord.x - 0.5) * (cancoord.x - 0.5) + (cancoord.y - 0.5) * (cancoord.y - 0.5);       
            float f = 0.0;
            f = (kcube == 0.0)? 1.0 + r2 * (k + kcube * sqrt(r2)) : 1.0 + r2 * k;
            vec2 coef = f * scale * (texcoord.xy - 0.5);
            vec2 rCoords = eta.r * coef + 0.5;
            vec2 gCoords = eta.g * coef + 0.5;
            vec2 bCoords = eta.b * coef + 0.5;
            vec4 inputDistort = vec4(0.0); 
            inputDistort.r = texture(fbColor, rCoords).r;
            inputDistort.g = texture(fbColor, gCoords).g;
            inputDistort.b = texture(fbColor, bCoords).b;
            inputDistort.a = 1.0;
            frag_color = inputDistort;
            frag_color.a = 1.0;
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
