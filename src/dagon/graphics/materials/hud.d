module dagon.graphics.materials.hud;

import std.stdio;
import std.math;
import std.conv;

import dlib.core.memory;
import dlib.math.vector;
import dlib.math.matrix;
import dlib.image.color;
import dlib.image.unmanaged;

import derelict.opengl.gl;

import dagon.core.ownership;
import dagon.graphics.rc;
import dagon.graphics.material;
import dagon.graphics.materials.generic;

class HUDMaterialBackend: GLSLMaterialBackend
{    
    private string vsText = 
    q{
        #version 330 core
        
        uniform mat4 modelViewMatrix;
        uniform mat4 projectionMatrix;
        
        layout (location = 0) in vec2 va_Vertex;
        layout (location = 1) in vec2 va_Texcoord;

        out vec2 texCoord;
        
        void main()
        {
            texCoord = va_Texcoord;
            gl_Position = projectionMatrix * modelViewMatrix * vec4(va_Vertex, 0.0, 1.0);
        }
    };
    
    private string fsText = q{
        #version 330 core
        
        uniform sampler2D diffuseTexture;
        
        in vec2 texCoord;
        
        out vec4 frag_color;

        void main()
        {
            frag_color = texture(diffuseTexture, texCoord);
        }
    };
    
    override string vertexShaderSrc() {return vsText;}
    override string fragmentShaderSrc() {return fsText;}

    GLint modelViewMatrixLoc;
    GLint projectionMatrixLoc;
    GLint diffuseTextureLoc;
    
    this(Owner o)
    {
        super(o);
        
        modelViewMatrixLoc = glGetUniformLocation(shaderProgram, "modelViewMatrix");
        projectionMatrixLoc = glGetUniformLocation(shaderProgram, "projectionMatrix");
        diffuseTextureLoc = glGetUniformLocation(shaderProgram, "diffuseTexture");
    }
    
    override void bind(GenericMaterial mat, RenderingContext* rc)
    {
        auto idiffuse = "diffuse" in mat.inputs;
    
        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
        glUseProgram(shaderProgram);
        
        // Matrices
        glUniformMatrix4fv(modelViewMatrixLoc, 1, GL_FALSE, rc.modelViewMatrix.arrayof.ptr);
        glUniformMatrix4fv(projectionMatrixLoc, 1, GL_FALSE, rc.projectionMatrix.arrayof.ptr);

        // Texture 0 - diffuse texture
        if (idiffuse.texture is null)
        {
            Color4f color = Color4f(idiffuse.asVector4f);
            idiffuse.texture = makeOnePixelTexture(mat, color);
        }
        glActiveTexture(GL_TEXTURE0);
        idiffuse.texture.bind();
        glUniform1i(diffuseTextureLoc, 0);
    }
    
    override void unbind(GenericMaterial mat)
    {
        glUseProgram(0);
        glDisable(GL_BLEND);
    }
}
