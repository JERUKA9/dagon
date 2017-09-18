module dagon.graphics.materials.shadeless;

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

class ShadelessBackend: GLSLMaterialBackend
{    
    private string vsText = q{
        #version 330 core
        
        layout (location = 0) in vec3 va_Vertex;
        
        uniform mat4 modelViewMatrix;
        uniform mat4 projectionMatrix;
    
        void main()
        {            
            gl_Position = projectionMatrix * modelViewMatrix * vec4(va_Vertex, 1.0);
        }
    };
    
    private string fsText = q{
        #version 330 core
        
        uniform vec4 color;
        
        out vec4 frag_color;

        void main()
        {
            frag_color = color;
        }
    };
    
    override string vertexShaderSrc() {return vsText;}
    override string fragmentShaderSrc() {return fsText;}

    GLint modelViewMatrixLoc;
    GLint projectionMatrixLoc;
    
    GLint locColor;
    
    this(Owner o)
    {
        super(o);
        
        modelViewMatrixLoc = glGetUniformLocation(shaderProgram, "modelViewMatrix");
        projectionMatrixLoc = glGetUniformLocation(shaderProgram, "projectionMatrix");
            
        locColor = glGetUniformLocation(shaderProgram, "color");
    }
    
    override void bind(GenericMaterial mat, RenderingContext* rc)
    {
        auto idiffuse = "diffuse" in mat.inputs;
    
        glUseProgram(shaderProgram);
        
        // Matrices
        glUniformMatrix4fv(modelViewMatrixLoc, 1, GL_FALSE, rc.modelViewMatrix.arrayof.ptr);
        glUniformMatrix4fv(projectionMatrixLoc, 1, GL_FALSE, rc.projectionMatrix.arrayof.ptr);

        Color4f color = Color4f(idiffuse.asVector4f);
        glUniform4fv(locColor, 1, color.arrayof.ptr);
    }
    
    override void unbind(GenericMaterial mat)
    {
        glUseProgram(0);
    }
}
