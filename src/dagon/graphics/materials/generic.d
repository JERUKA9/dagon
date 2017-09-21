module dagon.graphics.materials.generic;

import std.stdio;
import dlib.core.memory;
import dlib.math.vector;
import dlib.image.color;
import dlib.image.unmanaged;
import dlib.image.render.shapes;
import derelict.opengl.gl;
import dagon.core.ownership;
import dagon.graphics.material;
import dagon.graphics.texture;
import dagon.graphics.rc;

interface GenericMaterialBackend
{
    final bool boolProp(GenericMaterial mat, string prop)
    {
        auto p = prop in mat.inputs;
        bool res = false;
        if (p.type == MaterialInputType.Bool ||
            p.type == MaterialInputType.Integer)
        {
            res = p.asBool;
        }
        return res;
    }
    
    final int intProp(GenericMaterial mat, string prop)
    {
        auto p = prop in mat.inputs;
        int res = 0;
        if (p.type == MaterialInputType.Bool ||
            p.type == MaterialInputType.Integer)
        {
            res = p.asInteger;
        }
        else if (p.type == MaterialInputType.Float)
        {
            res = cast(int)p.asFloat;
        }
        return res;
    }
    
    final Texture makeOnePixelTexture(Material mat, Color4f color)
    {
        auto img = New!UnmanagedImageRGBA8(8, 8);
        img.fillColor(color);
        auto tex = New!Texture(img, mat, false);
        Delete(img);
        return tex;
    }
    
    void bind(GenericMaterial mat, RenderingContext* rc);
    void unbind(GenericMaterial mat);
}

enum int None = 0;

enum int ShadowFilterNone = 0;
enum int ShadowFilterPCF = 1;

enum int ParallaxNone = 0;
enum int ParallaxSimple = 1;
enum int ParallaxOcclusionMapping = 2;

class GenericMaterial: Material
{
    protected GenericMaterialBackend _backend;

    this(GenericMaterialBackend backend, Owner o)
    {
        super(o);

        setInput("diffuse", Color4f(0.8f, 0.8f, 0.8f, 1.0f));
        setInput("specular", Color4f(1.0f, 1.0f, 1.0f, 1.0f));
        setInput("shadeless", false);
        setInput("emit", Color4f(0.0f, 0.0f, 0.0f, 1.0f));
        setInput("alpha", 1.0f);
        setInput("brightness", 1.0f);
        setInput("roughness", 0.5f);
        setInput("metallic", 0.0f);
        setInput("normal", Vector3f(0.0f, 0.0f, 1.0f));
        setInput("height", 0.0f);
        setInput("parallax", ParallaxNone);
        setInput("parallaxScale", 0.03f);
        setInput("parallaxBias", -0.01f);
        setInput("shadowsEnabled", true);
        setInput("shadowFilter", ShadowFilterPCF);
        setInput("fogEnabled", true);

        _backend = backend;
    }

    GenericMaterialBackend backend()
    {
        return _backend;
    }

    void backend(GenericMaterialBackend b)
    {
        _backend = b;
    }

    override void bind(RenderingContext* rc)
    {
        if (_backend)
            _backend.bind(this, rc);
    }

    override void unbind()
    {
        if (_backend)
            _backend.unbind(this);
    }
}

abstract class GLSLMaterialBackend: Owner, GenericMaterialBackend
{
    string vertexShaderSrc();
    string fragmentShaderSrc();
    
    GLuint shaderProgram;
    GLuint vertexShader;
    GLuint fragmentShader;
    
    this(Owner o)
    {
        super(o);
        
        const(char*)pvs = vertexShaderSrc().ptr;
        const(char*)pfs = fragmentShaderSrc().ptr;
        
        char[1000] infobuffer = 0;
        int infobufferlen = 0;

        vertexShader = glCreateShader(GL_VERTEX_SHADER);
        glShaderSource(vertexShader, 1, &pvs, null);
        glCompileShader(vertexShader);
        GLint success = 0;
        glGetShaderiv(vertexShader, GL_COMPILE_STATUS, &success);
        if (!success)
        {
            GLint logSize = 0;
            glGetShaderiv(vertexShader, GL_INFO_LOG_LENGTH, &logSize);
            glGetShaderInfoLog(vertexShader, 999, &logSize, infobuffer.ptr);
            writeln("Error in vertex shader:");
            writeln(infobuffer[0..logSize]);
        }

        fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
        glShaderSource(fragmentShader, 1, &pfs, null);
        glCompileShader(fragmentShader);
        success = 0;
        glGetShaderiv(fragmentShader, GL_COMPILE_STATUS, &success);
        if (!success)
        {
            GLint logSize = 0;
            glGetShaderiv(fragmentShader, GL_INFO_LOG_LENGTH, &logSize);
            glGetShaderInfoLog(fragmentShader, 999, &logSize, infobuffer.ptr);
            writeln("Error in fragment shader:");
            writeln(infobuffer[0..logSize]);
        }

        shaderProgram = glCreateProgram();
        glAttachShader(shaderProgram, vertexShader);
        glAttachShader(shaderProgram, fragmentShader);
        glLinkProgram(shaderProgram);
    }
    
    void bind(GenericMaterial mat, RenderingContext* rc)
    {
        glUseProgram(shaderProgram);
    }
    
    void unbind(GenericMaterial mat)
    {
        glUseProgram(0);
    }
}
