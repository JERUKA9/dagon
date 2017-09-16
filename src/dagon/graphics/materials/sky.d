module dagon.graphics.materials.sky;

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

class SkyBackend: GLSLMaterialBackend
{    
    private string vsText = q{
        #version 330 core
        
        layout (location = 0) in vec3 va_Vertex;
        layout (location = 1) in vec3 va_Normal;
        
        uniform mat4 modelViewMatrix;
        uniform mat4 normalMatrix;
        uniform mat4 projectionMatrix;
        uniform mat4 invViewMatrix;
        
        out vec3 worldNormal;
    
        void main()
        {
            worldNormal = va_Normal;
            
            gl_Position = projectionMatrix * modelViewMatrix * vec4(va_Vertex, 1.0);
        }
    };
    
    private string fsText = q{
        #version 330 core
        
        uniform vec3 sunDirection;
        uniform vec3 skyZenithColor;
        uniform vec3 skyHorizonColor;
        uniform vec3 sunColor;
        
        in vec3 worldNormal;
        
        out vec4 frag_color;

        void main()
        {
            vec3 normalWorldN = normalize(worldNormal);
            float lambert = max(0.0, dot(-sunDirection, normalWorldN));
            float sun = pow(lambert, 200.0);
            vec3 horizon = mix(skyHorizonColor, sunColor, lambert);
            vec3 skyColor = mix(skyZenithColor, horizon, pow(length(normalWorldN.xz), 96.0));
            frag_color = vec4(skyColor + sunColor * sun, 1.0);
        }
    };
    
    override string vertexShaderSrc() {return vsText;}
    override string fragmentShaderSrc() {return fsText;}

    GLint modelViewMatrixLoc;
    GLint projectionMatrixLoc;
    GLint normalMatrixLoc;
    
    GLint locInvViewMatrix;
    GLint locSunDirection;
    GLint locSkyZenithColor;
    GLint locSkyHorizonColor;
    GLint locSunColor;
    
    this(Owner o)
    {
        super(o);
        
        modelViewMatrixLoc = glGetUniformLocation(shaderProgram, "modelViewMatrix");
        projectionMatrixLoc = glGetUniformLocation(shaderProgram, "projectionMatrix");
        normalMatrixLoc = glGetUniformLocation(shaderProgram, "normalMatrix");
            
        locInvViewMatrix = glGetUniformLocation(shaderProgram, "invViewMatrix");
        locSunDirection = glGetUniformLocation(shaderProgram, "sunDirection");
        locSkyZenithColor = glGetUniformLocation(shaderProgram, "skyZenithColor");
        locSkyHorizonColor = glGetUniformLocation(shaderProgram, "skyHorizonColor");
        locSunColor = glGetUniformLocation(shaderProgram, "sunColor");
    }
    
    override void bind(GenericMaterial mat, RenderingContext* rc)
    {
        glDepthMask(0);
    
        glUseProgram(shaderProgram);
        
        // Matrices
        glUniformMatrix4fv(modelViewMatrixLoc, 1, GL_FALSE, rc.modelViewMatrix.arrayof.ptr);
        glUniformMatrix4fv(projectionMatrixLoc, 1, GL_FALSE, rc.projectionMatrix.arrayof.ptr);
        glUniformMatrix4fv(normalMatrixLoc, 1, GL_FALSE, rc.normalMatrix.arrayof.ptr);
        glUniformMatrix4fv(locInvViewMatrix, 1, GL_FALSE, rc.invViewMatrix.arrayof.ptr);
        
        // Environment
        Vector3f sunVector = Vector4f(rc.environment.sunDirection);
        glUniform3fv(locSunDirection, 1, sunVector.arrayof.ptr);
        Vector3f sunColor = rc.environment.sunColor;
        glUniform3fv(locSunColor, 1, sunColor.arrayof.ptr);
        glUniform3fv(locSkyZenithColor, 1, rc.environment.skyZenithColor.arrayof.ptr);
        glUniform3fv(locSkyHorizonColor, 1, rc.environment.skyHorizonColor.arrayof.ptr);
    }
    
    override void unbind(GenericMaterial mat)
    {
        glUseProgram(0);
        
        glDepthMask(1);
    }
}
