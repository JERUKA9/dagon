module dagon.graphics.postproc;

import std.stdio;
import std.conv;

import dlib.math.vector;

import derelict.opengl.gl;

import dagon.core.ownership;
import dagon.graphics.rc;
import dagon.graphics.framebuffer;

class PostFilter: Owner
{
    Framebuffer fb;
    
    GLenum shaderVert;
    GLenum shaderFrag;
    GLenum shaderProgram;
    
    GLint modelViewMatrixLoc;
    GLint projectionMatrixLoc;
    GLint fbColorLoc;
    GLint fbDepthLoc;
    GLint viewportSizeLoc;
    
    private string vsText = 
    q{
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
    
    private string fsText =
    q{
        #version 330 core
        
        uniform sampler2D fbColor;
        uniform sampler2D fbDepth;
        uniform vec2 viewSize;

        in vec2 texCoord;
        out vec4 frag_color;
        
        void main()
        {
            vec4 t = texture(fbColor, texCoord);
            frag_color = t;
            frag_color.a = 1.0;
        }
    };
    
    string vertexShader() {return vsText;}
    string fragmentShader() {return fsText;}

    this(Framebuffer fb, Owner o)
    {
        super(o);
        
        this.fb = fb;
        
        const(char*)pvs = vertexShader().ptr;
        const(char*)pfs = fragmentShader().ptr;
        
        char[1000] infobuffer = 0;
        int infobufferlen = 0;

        shaderVert = glCreateShader(GL_VERTEX_SHADER);
        glShaderSource(shaderVert, 1, &pvs, null);
        glCompileShader(shaderVert);
        GLint success = 0;
        glGetShaderiv(shaderVert, GL_COMPILE_STATUS, &success);
        if (!success)
        {
            GLint logSize = 0;
            glGetShaderiv(shaderVert, GL_INFO_LOG_LENGTH, &logSize);
            glGetShaderInfoLog(shaderVert, 999, &logSize, infobuffer.ptr);
            writeln("Error in vertex shader:");
            writeln(infobuffer[0..logSize]);
        }

        shaderFrag = glCreateShader(GL_FRAGMENT_SHADER);
        glShaderSource(shaderFrag, 1, &pfs, null);
        glCompileShader(shaderFrag);
        success = 0;
        glGetShaderiv(shaderFrag, GL_COMPILE_STATUS, &success);
        if (!success)
        {
            GLint logSize = 0;
            glGetShaderiv(shaderFrag, GL_INFO_LOG_LENGTH, &logSize);
            glGetShaderInfoLog(shaderFrag, 999, &logSize, infobuffer.ptr);
            writeln("Error in fragment shader:");
            writeln(infobuffer[0..logSize]);
        }

        shaderProgram = glCreateProgram();
        glAttachShader(shaderProgram, shaderVert);
        glAttachShader(shaderProgram, shaderFrag);
        glLinkProgram(shaderProgram);
        
        modelViewMatrixLoc = glGetUniformLocation(shaderProgram, "modelViewMatrix");
        projectionMatrixLoc = glGetUniformLocation(shaderProgram, "projectionMatrix");

        viewportSizeLoc = glGetUniformLocation(shaderProgram, "viewSize");
        fbColorLoc = glGetUniformLocation(shaderProgram, "fbColor");
        fbDepthLoc = glGetUniformLocation(shaderProgram, "fbDepth");
    }
    
    void render(RenderingContext* rc)
    {
        glUseProgram(shaderProgram);
        
        glUniformMatrix4fv(modelViewMatrixLoc, 1, 0, rc.modelViewMatrix.arrayof.ptr);
        glUniformMatrix4fv(projectionMatrixLoc, 1, 0, rc.projectionMatrix.arrayof.ptr);
        
        Vector2f viewportSize = Vector2f(fb.width, fb.height);
        glUniform2fv(viewportSizeLoc, 1, viewportSize.arrayof.ptr);

        glUniform1i(fbColorLoc, 0);
        glUniform1i(fbDepthLoc, 1);
 
        fb.render();
        
        glUseProgram(0);
    }
}
