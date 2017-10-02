module dagon.graphics.materials.terrain;

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
import dagon.graphics.shadow;
import dagon.graphics.clustered;
import dagon.graphics.material;
import dagon.graphics.materials.generic;

class TerrainBackend: GLSLMaterialBackend
{    
    private string vsText = q{
        #version 330 core
        
        layout (location = 0) in vec3 va_Vertex;
        layout (location = 1) in vec3 va_Normal;
        layout (location = 2) in vec2 va_Texcoord;
        
        out vec2 texCoord;
        out vec3 eyePosition;
        out vec3 worldPosition;
        out vec3 eyeNormal;
        out vec3 worldNormal;
        
        out vec4 shadowCoord1;
        out vec4 shadowCoord2;
        out vec4 shadowCoord3;
        
        uniform mat4 modelViewMatrix;
        uniform mat4 normalMatrix;
        uniform mat4 projectionMatrix;
        uniform mat4 invViewMatrix;
        
        uniform mat4 shadowMatrix1;
        uniform mat4 shadowMatrix2;
        uniform mat4 shadowMatrix3;
        
        const float texScale = 100.0;
        const float eyeSpaceNormalShift = 0.05;
    
        void main()
        {
            texCoord = va_Texcoord * texScale;
            worldNormal = va_Normal;
            eyeNormal = (normalMatrix * vec4(va_Normal, 0.0)).xyz;
            
            vec4 pos = modelViewMatrix * vec4(va_Vertex, 1.0);
            eyePosition = pos.xyz;
            
            worldPosition = (invViewMatrix * pos).xyz;
            
            vec4 posShifted = pos + vec4(eyeNormal * eyeSpaceNormalShift, 0.0);
            shadowCoord1 = shadowMatrix1 * posShifted;
            shadowCoord2 = shadowMatrix2 * posShifted;
            shadowCoord3 = shadowMatrix3 * posShifted;
            
            gl_Position = projectionMatrix * pos;
        }
    };
    
    private string fsText = q{
        #version 330 core
        
        in vec2 texCoord;
        in vec3 eyePosition;
        in vec3 worldPosition;
        in vec3 eyeNormal;
        in vec3 worldNormal;
        
        in vec4 shadowCoord1;
        in vec4 shadowCoord2;
        in vec4 shadowCoord3;
        
        out vec4 frag_color;
        
        uniform mat4 viewMatrix;
        uniform mat4 invViewMatrix;
        
        uniform float roughness;
        
        uniform sampler2D grassTexture;
        uniform sampler2D mountsTexture;
        
        uniform sampler2D grassNormalTexture;
        uniform sampler2D mountsNormalTexture;
        
        uniform sampler2DArrayShadow shadowTextureArray;
        uniform float shadowTextureSize;
        uniform bool useShadows;
        
        uniform float invLightDomainSize;
        uniform usampler2D lightClusterTexture;
        uniform usampler1D lightIndexTexture;
        uniform sampler2D lightsTexture;
        
        uniform vec4 environmentColor;
        uniform vec3 sunDirection;
        uniform vec3 sunColor;
        uniform vec4 fogColor;
        uniform float fogStart;
        uniform float fogEnd;
        
        mat3 cotangentFrame(in vec3 N, in vec3 p, in vec2 uv)
        {
            vec3 dp1 = dFdx(p);
            vec3 dp2 = dFdy(p);
            vec2 duv1 = dFdx(uv);
            vec2 duv2 = dFdy(uv);
            vec3 dp2perp = cross(dp2, N);
            vec3 dp1perp = cross(N, dp1);
            vec3 T = dp2perp * duv1.x + dp1perp * duv2.x;
            vec3 B = dp2perp * duv1.y + dp1perp * duv2.y;
            float invmax = inversesqrt(max(dot(T, T), dot(B, B)));
            return mat3(T * invmax, B * invmax, N);
        }
        
        float shadowLookup(in sampler2DArrayShadow depths, in float layer, in vec4 coord, in vec2 offset)
        {
            float texelSize = 1.0 / shadowTextureSize;
            vec2 v = offset * texelSize * coord.w;
            vec4 c = (coord + vec4(v.x, v.y, 0.0, 0.0)) / coord.w;
            c.w = c.z;
            c.z = layer;
            float s = texture(depths, c);
            return s;
        }
        
        float pcf(in sampler2DArrayShadow depths, in float layer, in vec4 coord, in float radius, in float yshift)
        {
            float s = 0.0;
            float x, y;
	        for (y = -radius ; y < radius ; y += 1.0)
	        for (x = -radius ; x < radius ; x += 1.0)
            {
	            s += shadowLookup(depths, layer, coord, vec2(x, y + yshift));
            }
	        s /= radius * radius * 4.0;
            return s;
        }
        
        float weight(in vec4 tc)
        {
            vec2 proj = vec2(tc.x / tc.w, tc.y / tc.w);
            proj = (1.0 - abs(proj * 2.0 - 1.0)) * 8.0;
            proj = clamp(proj, 0.0, 1.0);
            return min(proj.x, proj.y);
        }
        
        void main()
        {
            vec3 N = normalize(eyeNormal);
            vec3 Nw = normalize(worldNormal);
            vec3 E = normalize(-eyePosition);
            
            mat3 TBN = cotangentFrame(N, eyePosition, texCoord);
            vec3 tE = normalize(E * TBN);
            
            vec3 cameraPosition = invViewMatrix[3].xyz;
            
            float slope = pow(dot(Nw, vec3(0.0, 1.0, 0.0)), 5.0);
            
            // Normal mapping
            vec3 tN1 = normalize(texture(grassNormalTexture, texCoord).rgb * 2.0 - 1.0);
            tN1.y = -tN1.y;
            vec3 N1 = normalize(TBN * tN1);

            vec3 tN2 = normalize(texture(mountsNormalTexture, texCoord).rgb * 2.0 - 1.0);
            tN2.y = -tN2.y;
            vec3 N2 = normalize(TBN * tN1);
            
            // Roughness to blinn-phong specular power
            float gloss = 1.0 - roughness;
            float shininess = gloss * 128.0;
            
            // Sun light
            float sunDiffBrightness1 = clamp(dot(N1, sunDirection), 0.0, 1.0);
            float sunDiffBrightness2 = clamp(dot(N2, sunDirection), 0.0, 1.0);
            
            // Calculate shadow from 3 cascades
            float s1, s2, s3;
            if (useShadows)
            {
                s1 = pcf(shadowTextureArray, 0.0, shadowCoord1, 3.0, 0.0);
                s2 = pcf(shadowTextureArray, 1.0, shadowCoord2, 2.0, 0.0);
                s3 = pcf(shadowTextureArray, 2.0, shadowCoord3, 1.0, 0.0);
                float w1 = weight(shadowCoord1);
                float w2 = weight(shadowCoord2);
                float w3 = weight(shadowCoord3);
                s3 = mix(1.0, s3, w3); 
                s2 = mix(s3, s2, w2);
                s1 = mix(s2, s1, w1); // s1 stores resulting shadow value
            }
            else
            {
                s1 = 1.0f;
            }
            
            vec3 R = reflect(E, N);
            
            // Fetch light cluster slice
            vec2 clusterCoord = (worldPosition.xz - cameraPosition.xz) * invLightDomainSize + 0.5;
            uint clusterIndex = texture(lightClusterTexture, clusterCoord).r;
            uint offset = (clusterIndex << 16) >> 16;
            uint size = (clusterIndex >> 16);
            
            vec3 pointDiffSum = vec3(0.0, 0.0, 0.0);
            vec3 pointSpecSum = vec3(0.0, 0.0, 0.0);
            for (uint i = 0u; i < size; i++)
            {
                // Read light data
                uint u = texelFetch(lightIndexTexture, int(offset + i), 0).r;
                vec3 lightPos = texelFetch(lightsTexture, ivec2(u, 0), 0).xyz; 
                vec3 lightColor = texelFetch(lightsTexture, ivec2(u, 1), 0).xyz; 
                vec3 lightProps = texelFetch(lightsTexture, ivec2(u, 2), 0).xyz;
                float lightRadius = lightProps.x;
                float lightAreaRadius = lightProps.y;
                float lightEnergy = lightProps.z;
                
                vec3 lightPosEye = (viewMatrix * vec4(lightPos, 1.0)).xyz;
                
                vec3 positionToLightSource = lightPosEye - eyePosition;
                float distanceToLight = length(positionToLightSource);
                vec3 directionToLight = normalize(positionToLightSource);                
                float attenuation = clamp(1.0 - (distanceToLight / lightRadius), 0.0, 1.0) * lightEnergy;
                
                float diff = clamp(dot(N, directionToLight), 0.0, 1.0);
                pointDiffSum += lightColor * diff * attenuation;
            }
            
            // Fog
            float fogDistance = gl_FragCoord.z / gl_FragCoord.w;
            float fogFactor = clamp((fogEnd - fogDistance) / (fogEnd - fogStart), 0.0, 1.0);
            
            vec3 colorGrass = texture(grassTexture, texCoord).rgb; //vec3(0.0, 0.5, 0.0);
            vec3 colorMounts = texture(mountsTexture, texCoord).rgb; 
            vec3 diffColor = mix(colorMounts, colorGrass, slope);
            
            float diffuse = mix(sunDiffBrightness2, sunDiffBrightness1, slope);
            
            vec3 objColor = diffColor * (environmentColor.rgb + pointDiffSum + sunColor * diffuse * s1);
            
            vec3 fragColor = mix(fogColor.rgb, objColor, fogFactor);
            
            frag_color = vec4(fragColor, 1.0);
        }
    };
    
    override string vertexShaderSrc() {return vsText;}
    override string fragmentShaderSrc() {return fsText;}

    GLint viewMatrixLoc;
    GLint modelViewMatrixLoc;
    GLint projectionMatrixLoc;
    GLint normalMatrixLoc;
    GLint invViewMatrixLoc;
    
    GLint environmentColorLoc;
    GLint sunDirectionLoc;
    GLint sunColorLoc;
    GLint fogStartLoc;
    GLint fogEndLoc;
    GLint fogColorLoc;
    
    GLint shadowMatrix1Loc;
    GLint shadowMatrix2Loc; 
    GLint shadowMatrix3Loc;
    GLint shadowTextureArrayLoc;
    GLint shadowTextureSizeLoc;
    GLint useShadowsLoc;
    
    GLint grassTextureLoc;
    GLint mountsTextureLoc;
    GLint grassNormalTextureLoc;
    
    GLint invLightDomainSizeLoc;
    GLint clusterTextureLoc;
    GLint lightsTextureLoc;
    GLint indexTextureLoc;
    
    ClusteredLightManager lightManager;
    CascadedShadowMap shadowMap;
    Matrix4x4f defaultShadowMat;
    Vector3f defaultLightDir;
    
    this(ClusteredLightManager clm, Owner o)
    {
        super(o);
        
        lightManager = clm;
        
        viewMatrixLoc = glGetUniformLocation(shaderProgram, "viewMatrix");
        modelViewMatrixLoc = glGetUniformLocation(shaderProgram, "modelViewMatrix");
        projectionMatrixLoc = glGetUniformLocation(shaderProgram, "projectionMatrix");
        normalMatrixLoc = glGetUniformLocation(shaderProgram, "normalMatrix");
        invViewMatrixLoc = glGetUniformLocation(shaderProgram, "invViewMatrix");
        
        environmentColorLoc = glGetUniformLocation(shaderProgram, "environmentColor");
        sunDirectionLoc = glGetUniformLocation(shaderProgram, "sunDirection");
        sunColorLoc = glGetUniformLocation(shaderProgram, "sunColor");
        fogStartLoc = glGetUniformLocation(shaderProgram, "fogStart");
        fogEndLoc = glGetUniformLocation(shaderProgram, "fogEnd");
        fogColorLoc = glGetUniformLocation(shaderProgram, "fogColor");
        
        shadowMatrix1Loc = glGetUniformLocation(shaderProgram, "shadowMatrix1");
        shadowMatrix2Loc = glGetUniformLocation(shaderProgram, "shadowMatrix2");
        shadowMatrix3Loc = glGetUniformLocation(shaderProgram, "shadowMatrix3");
        shadowTextureArrayLoc = glGetUniformLocation(shaderProgram, "shadowTextureArray");
        shadowTextureSizeLoc = glGetUniformLocation(shaderProgram, "shadowTextureSize");
        useShadowsLoc = glGetUniformLocation(shaderProgram, "useShadows");
            
        grassTextureLoc = glGetUniformLocation(shaderProgram, "grassTexture");
        mountsTextureLoc = glGetUniformLocation(shaderProgram, "mountsTexture");
        grassNormalTextureLoc = glGetUniformLocation(shaderProgram, "grassNormalTexture");
        
        clusterTextureLoc = glGetUniformLocation(shaderProgram, "lightClusterTexture");
        invLightDomainSizeLoc = glGetUniformLocation(shaderProgram, "invLightDomainSize");
        lightsTextureLoc = glGetUniformLocation(shaderProgram, "lightsTexture");
        indexTextureLoc = glGetUniformLocation(shaderProgram, "lightIndexTexture");
    }
    
    override void bind(GenericMaterial mat, RenderingContext* rc)
    {
        auto igrass = "grass" in mat.inputs;
        if (igrass is null)
            igrass = mat.setInput("grass", Color4f(0.0f, 0.5f, 0.0f, 1.0f));
            
        auto imounts = "mounts" in mat.inputs;
        if (imounts is null)
            imounts = mat.setInput("mounts", Color4f(0.2f, 0.2f, 0.2f, 1.0f));
            
        auto igrassNormal = "grassNormal" in mat.inputs;
        if (igrassNormal is null)
            igrassNormal = mat.setInput("grassNormal", Color4f(0.0f, 0.0f, 0.0f, 0.0f));
            
        bool fogEnabled = boolProp(mat, "fogEnabled");
        bool shadowsEnabled = boolProp(mat, "shadowsEnabled");

        glUseProgram(shaderProgram);
        
        // Matrices
        glUniformMatrix4fv(viewMatrixLoc, 1, GL_FALSE, rc.viewMatrix.arrayof.ptr);
        glUniformMatrix4fv(modelViewMatrixLoc, 1, GL_FALSE, rc.modelViewMatrix.arrayof.ptr);
        glUniformMatrix4fv(projectionMatrixLoc, 1, GL_FALSE, rc.projectionMatrix.arrayof.ptr);
        glUniformMatrix4fv(normalMatrixLoc, 1, GL_FALSE, rc.normalMatrix.arrayof.ptr);
        glUniformMatrix4fv(invViewMatrixLoc, 1, GL_FALSE, rc.invViewMatrix.arrayof.ptr);
        
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

        // Texture 0 - grass texture
        if (igrass.texture is null)
        {
            Color4f color = Color4f(igrass.asVector4f);
            igrass.texture = makeOnePixelTexture(mat, color);
        }
        glActiveTexture(GL_TEXTURE0);
        igrass.texture.bind();
        glUniform1i(grassTextureLoc, 0);
        
        // Texture 1 - mounts texture
        if (imounts.texture is null)
        {
            Color4f color = Color4f(imounts.asVector4f);
            imounts.texture = makeOnePixelTexture(mat, color);
        }
        glActiveTexture(GL_TEXTURE1);
        imounts.texture.bind();
        glUniform1i(mountsTextureLoc, 1);
        
        // Texture 2 - grass normal map
        if (igrassNormal.texture is null)
        {
            Color4f color = Color4f(0.5f, 0.5f, 1.0f, 0.0f); // default normal pointing upwards
            igrassNormal.texture = makeOnePixelTexture(mat, color);
        }
        glActiveTexture(GL_TEXTURE2);
        igrassNormal.texture.bind();
        glUniform1i(grassNormalTextureLoc, 2);
        
        // Texture 5 - shadow map cascades (3 layer texture array)
        if (shadowMap && shadowsEnabled)
        {
            glActiveTexture(GL_TEXTURE5);
            glBindTexture(GL_TEXTURE_2D_ARRAY, shadowMap.depthTexture);

            glUniform1i(shadowTextureArrayLoc, 5);
            glUniform1f(shadowTextureSizeLoc, cast(float)shadowMap.size);
            glUniformMatrix4fv(shadowMatrix1Loc, 1, 0, shadowMap.area1.shadowMatrix.arrayof.ptr);
            glUniformMatrix4fv(shadowMatrix2Loc, 1, 0, shadowMap.area2.shadowMatrix.arrayof.ptr);
            glUniformMatrix4fv(shadowMatrix3Loc, 1, 0, shadowMap.area3.shadowMatrix.arrayof.ptr);
            glUniform1i(useShadowsLoc, 1);
            
            // TODO: shadowFilter
        }
        else
        {        
            glUniformMatrix4fv(shadowMatrix1Loc, 1, 0, defaultShadowMat.arrayof.ptr);
            glUniformMatrix4fv(shadowMatrix2Loc, 1, 0, defaultShadowMat.arrayof.ptr);
            glUniformMatrix4fv(shadowMatrix3Loc, 1, 0, defaultShadowMat.arrayof.ptr);
            glUniform1i(useShadowsLoc, 0);
        }
        
        // Texture 6 - light clusters
        glActiveTexture(GL_TEXTURE6);
        lightManager.bindClusterTexture();
        glUniform1i(clusterTextureLoc, 6);
        glUniform1f(invLightDomainSizeLoc, lightManager.invSceneSize);
        
        // Texture 7 - light data
        glActiveTexture(GL_TEXTURE7);
        lightManager.bindLightTexture();
        glUniform1i(lightsTextureLoc, 7);
        
        // Texture 8 - light indices per cluster
        glActiveTexture(GL_TEXTURE8);
        lightManager.bindIndexTexture();
        glUniform1i(indexTextureLoc, 8);
    }
    
    override void unbind(GenericMaterial mat)
    {
        auto igrass = "grass" in mat.inputs;
        auto imounts = "mounts" in mat.inputs;
        auto igrassNormal = "grassNormal" in mat.inputs;
        
        glActiveTexture(GL_TEXTURE0);
        igrass.texture.unbind();
        
        glActiveTexture(GL_TEXTURE1);
        imounts.texture.unbind();
        
        glActiveTexture(GL_TEXTURE2);
        igrassNormal.texture.unbind();
        
        glActiveTexture(GL_TEXTURE5);
        glBindTexture(GL_TEXTURE_2D_ARRAY, 0);
        
        glActiveTexture(GL_TEXTURE6);
        lightManager.unbindClusterTexture();
        
        glActiveTexture(GL_TEXTURE7);
        lightManager.unbindLightTexture();
        
        glActiveTexture(GL_TEXTURE8);
        lightManager.unbindIndexTexture();
        
        glActiveTexture(GL_TEXTURE0);
        
        glUseProgram(0);
    }
}
