module dagon.graphics.materials.cloud;

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

class CloudBackend: GLSLMaterialBackend
{    
    private string vsText = q{
        #version 330 core
        
        layout (location = 0) in vec3 va_Vertex;
        layout (location = 2) in vec2 va_Texcoord;
        
        out vec2 texCoord;
        out vec3 eyePosition;
        
        uniform mat4 modelViewMatrix;
        uniform mat4 projectionMatrix;
        
        uniform float time;
    
        void main()
        {
            texCoord = va_Texcoord;
            texCoord.x += time;
            vec4 pos = modelViewMatrix * vec4(va_Vertex, 1.0);
            eyePosition = pos.xyz;
            gl_Position = projectionMatrix *  pos;
        }
    };
    
    private string fsText = q{
        #version 330 core
        
        uniform sampler2D diffuseTexture;
        
        uniform vec4 environmentColor;
        uniform vec3 sunDirection;
        uniform vec3 sunColor;
        uniform vec4 fogColor;
        uniform float fogStart;
        uniform float fogEnd;
        
        in vec2 texCoord;
        in vec3 eyePosition;
        
        out vec4 frag_color;
        
        const float maxDistance = 1000.0;

        void main()
        {
            vec3 E = normalize(eyePosition);
            float distance = length(eyePosition);
            float distanceFactor = pow(clamp(distance / maxDistance, 0.0, 1.0), 3.0);

            float fogDistance = gl_FragCoord.z / gl_FragCoord.w;
            float fogFactor = clamp((fogEnd - fogDistance) / (fogEnd - fogStart), 0.0, 1.0);
            
            vec4 diffuseColor = texture(diffuseTexture, texCoord);
            
            float diff = (dot(sunDirection, E) + 1.0) * 0.5;
            vec3 color = diffuseColor.rgb * (environmentColor.rgb * 2.0 + sunColor * diff);

            float fragAlpha = mix(diffuseColor.a, 0.0f, distanceFactor);
            
            frag_color = vec4(color, fragAlpha);
        }
    };
    
    override string vertexShaderSrc() {return vsText;}
    override string fragmentShaderSrc() {return fsText;}

    GLint modelViewMatrixLoc;
    GLint projectionMatrixLoc;
    
    GLint diffuseTextureLoc;
    
    GLint environmentColorLoc;
    GLint sunDirectionLoc;
    GLint sunColorLoc;
    GLint fogStartLoc;
    GLint fogEndLoc;
    GLint fogColorLoc;
    GLint timeLoc;
    
    float time = 0.0;
    
    this(Owner o)
    {
        super(o);
        
        modelViewMatrixLoc = glGetUniformLocation(shaderProgram, "modelViewMatrix");
        projectionMatrixLoc = glGetUniformLocation(shaderProgram, "projectionMatrix");
            
        diffuseTextureLoc = glGetUniformLocation(shaderProgram, "diffuseTexture");
        
        environmentColorLoc = glGetUniformLocation(shaderProgram, "environmentColor");
        sunDirectionLoc = glGetUniformLocation(shaderProgram, "sunDirection");
        sunColorLoc = glGetUniformLocation(shaderProgram, "sunColor");
        fogStartLoc = glGetUniformLocation(shaderProgram, "fogStart");
        fogEndLoc = glGetUniformLocation(shaderProgram, "fogEnd");
        fogColorLoc = glGetUniformLocation(shaderProgram, "fogColor");
        
        timeLoc = glGetUniformLocation(shaderProgram, "time");
    }
    
    override void bind(GenericMaterial mat, RenderingContext* rc)
    {
        auto idiffuse = "diffuse" in mat.inputs;
        bool fogEnabled = boolProp(mat, "fogEnabled");
        auto itimeScale = "timeScale" in mat.inputs;
    
        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glDepthMask(GL_FALSE);
    
        glUseProgram(shaderProgram);
        
        // Matrices
        glUniformMatrix4fv(modelViewMatrixLoc, 1, GL_FALSE, rc.modelViewMatrix.arrayof.ptr);
        glUniformMatrix4fv(projectionMatrixLoc, 1, GL_FALSE, rc.projectionMatrix.arrayof.ptr);
        
        // Environment parameters
        Color4f environmentColor = Color4f(0.0f, 0.0f, 0.0f, 1.0f);
        Vector4f sunHGVector = Vector4f(0.0f, 1.0f, 0.0, 0.0f);
        Vector3f sunColor = Vector3f(1.0f, 1.0f, 1.0f);
        if (rc.environment)
        {
            environmentColor = rc.environment.ambientConstant;
            sunHGVector = Vector4f(rc.environment.sunDirection);
            sunHGVector.w = 0.0;
            sunColor = rc.environment.sunColor;
        }
        glUniform4fv(environmentColorLoc, 1, environmentColor.arrayof.ptr);
        Vector3f sunDirectionEye = sunHGVector * rc.viewMatrix;
        glUniform3fv(sunDirectionLoc, 1, sunDirectionEye.arrayof.ptr);
        glUniform3fv(sunColorLoc, 1, sunColor.arrayof.ptr);
        Color4f fogColor = Color4f(0.0f, 0.0f, 0.0f, 1.0f);
        float fogStart = float.max;
        float fogEnd = float.max;
        if (fogEnabled)
        {
            if (rc.environment)
            {                
                fogColor = rc.environment.fogColor;
                fogStart = rc.environment.fogStart;
                fogEnd = rc.environment.fogEnd;
            }
        }
        glUniform4fv(fogColorLoc, 1, fogColor.arrayof.ptr);
        glUniform1f(fogStartLoc, fogStart);
        glUniform1f(fogEndLoc, fogEnd);
        
        float scrollSpeed = 0.0;
        if (itimeScale)
            scrollSpeed = itimeScale.asFloat;
        glUniform1f(timeLoc, rc.time * scrollSpeed);

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
        glDepthMask(GL_TRUE);
        glDisable(GL_BLEND);
    }
}
