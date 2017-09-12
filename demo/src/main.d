module main;

import std.stdio;

import dagon;

class SimpleBackend: GLSLMaterialBackend
{
    string vsText = 
    q{
        #version 330 core
        
        uniform mat4 modelViewMatrix;
        uniform mat4 normalMatrix;
        uniform mat4 projectionMatrix;
        
        layout (location = 0) in vec3 va_Vertex;
        layout (location = 1) in vec3 va_Normal;
        layout (location = 2) in vec2 va_Texcoord;
        
        out vec3 eyePosition;
        out vec3 eyeNormal;
        out vec2 texCoord;
        
        void main()
        {
            texCoord = va_Texcoord;
            eyeNormal = (normalMatrix * vec4(va_Normal, 0.0)).xyz;
            vec4 pos = modelViewMatrix * vec4(va_Vertex, 1.0);
            eyePosition = pos.xyz;
            gl_Position = projectionMatrix * pos;
        }
    };

    string fsText =
    q{
        #version 330 core
        
        uniform mat4 viewMatrix;
        uniform sampler2D diffuseTexture;
        uniform sampler2D normalTexture;
        
        in vec3 eyePosition;
        in vec3 eyeNormal;
        in vec2 texCoord;
        
        out vec4 frag_color;
        
        const vec4 lightPos = vec4(0.0, 8.0, 4.0, 1.0);
        
        mat3 cotangentFrame(vec3 N, vec3 p, vec2 uv)
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
        
        void main()
        {
            vec3 L = (viewMatrix * lightPos).xyz;
            L = normalize(L - eyePosition);
                        
            vec3 N = normalize(eyeNormal);
            vec3 E = normalize(-eyePosition);
            
            mat3 TBN = cotangentFrame(eyeNormal, eyePosition, texCoord);
            
            vec3 tN = normalize(texture2D(normalTexture, texCoord).rgb * 2.0 - 1.0);
            tN.y = -tN.y;
            N = normalize(TBN * tN);
            
            const float ambient = 0.3;
            
            float roughness = 0.3;
            float gloss = 1.0 - roughness;
            float shininess = gloss * 128.0;
            
            float diffuse = clamp(dot(L, N), 0.0, 1.0);
            
            vec3 hE = normalize(L + E);
            float NH = dot(N, hE);
            float specular = pow(max(NH, 0.0), shininess) * gloss;
            
            vec4 tex = texture(diffuseTexture, texCoord);
            frag_color = tex * ambient + tex * diffuse * (1.0 - ambient) + vec4(1.0) * specular;
            frag_color.a = 1.0;
        }
    };
    
    override string vertexShaderSrc() {return vsText;}
    override string fragmentShaderSrc() {return fsText;}

    GLint viewMatrixLoc;
    GLint modelViewMatrixLoc;
    GLint projectionMatrixLoc;
    GLint normalMatrixLoc;
    
    GLint diffuseTextureLoc;
    GLint normalTextureLoc;
    
    this(Owner o)
    {
        super(o);

        viewMatrixLoc = glGetUniformLocation(shaderProgram, "viewMatrix");
        modelViewMatrixLoc = glGetUniformLocation(shaderProgram, "modelViewMatrix");
        projectionMatrixLoc = glGetUniformLocation(shaderProgram, "projectionMatrix");
        normalMatrixLoc = glGetUniformLocation(shaderProgram, "normalMatrix");
        
        diffuseTextureLoc = glGetUniformLocation(shaderProgram, "diffuseTexture");
        normalTextureLoc = glGetUniformLocation(shaderProgram, "normalTexture");
    }
    
    Texture makeOnePixelTexture(Material mat, Color4f color)
    {
        auto img = New!UnmanagedImageRGBA8(8, 8);
        img.fillColor(color);
        auto tex = New!Texture(img, mat, false);
        Delete(img);
        return tex;
    }
    
    override void bind(GenericMaterial mat, RenderingContext* rc)
    {
        auto idiffuse = "diffuse" in mat.inputs;
        auto inormal = "normal" in mat.inputs;
        
        glEnable(GL_CULL_FACE);
        
        glUseProgram(shaderProgram);
        
        // Matrices
        glUniformMatrix4fv(viewMatrixLoc, 1, GL_FALSE, rc.viewMatrix.arrayof.ptr);
        glUniformMatrix4fv(modelViewMatrixLoc, 1, GL_FALSE, rc.modelViewMatrix.arrayof.ptr);
        glUniformMatrix4fv(projectionMatrixLoc, 1, GL_FALSE, rc.projectionMatrix.arrayof.ptr);
        glUniformMatrix4fv(normalMatrixLoc, 1, GL_FALSE, rc.normalMatrix.arrayof.ptr);
        
        // Texture 0 - diffuse texture
        if (idiffuse.texture is null)
        {
            Color4f color = Color4f(idiffuse.asVector4f);
            idiffuse.texture = makeOnePixelTexture(mat, color);
        }
        glActiveTexture(GL_TEXTURE0);
        idiffuse.texture.bind();
        glUniform1i(diffuseTextureLoc, 0);
        
        // Texture 1 - normal map
        if (inormal.texture is null)
        {
            Color4f color = Color4f(0.5f, 0.5f, 1.0f); // default normal pointing upwards
            inormal.texture = makeOnePixelTexture(mat, color);
        }
        glActiveTexture(GL_TEXTURE1);
        inormal.texture.bind();
        glUniform1i(normalTextureLoc, 1);
    }
    
    override void unbind(GenericMaterial mat)
    {
        auto idiffuse = "diffuse" in mat.inputs;
        auto inormal = "normal" in mat.inputs;
        
        glActiveTexture(GL_TEXTURE0);
        idiffuse.texture.unbind();
        
        glActiveTexture(GL_TEXTURE1);
        inormal.texture.unbind();
        
        glUseProgram(0);
    }
}

class TestScene: BaseScene3D
{
    TextureAsset aTexImrodDiffuse;
    TextureAsset aTexImrodNormal;
    
    TextureAsset aTexStoneDiffuse;
    TextureAsset aTexStoneNormal;
    
    OBJAsset obj;
    
    SimpleBackend sb;

    this(SceneManager smngr)
    {
        super(smngr);
    }

    override void onAssetsRequest()
    {
        aTexImrodDiffuse = addTextureAsset("data/obj/imrod-diffuse.png");
        aTexImrodNormal = addTextureAsset("data/obj/imrod-normal.png");
        
        aTexStoneDiffuse = addTextureAsset("data/textures/stone-albedo.png");
        aTexStoneNormal = addTextureAsset("data/textures/stone-normal.png");
        
        obj = New!OBJAsset(assetManager);
        addAsset(obj, "data/obj/imrod.obj");
    }

    override void onAllocate()
    {
        super.onAllocate();
        
        auto freeview = New!Freeview(eventManager, assetManager);
        freeview.setZoom(15.0f);
        view = freeview;
        
        sb = New!SimpleBackend(assetManager);
        
        auto mat1 = New!GenericMaterial(sb, assetManager);
        mat1.diffuse = aTexImrodDiffuse.texture;
        mat1.normal = aTexImrodNormal.texture;
        
        auto mat2 = New!GenericMaterial(sb, assetManager);
        mat2.diffuse = aTexStoneDiffuse.texture;
        mat2.normal = aTexStoneNormal.texture;
        
        Entity e = New!Entity(eventManager, assetManager);
        entities3D.append(e);
        e.drawable = obj.mesh;
        e.material = mat1;
        
        Entity ePlane = New!Entity(eventManager, assetManager);
        entities3D.append(ePlane);
        ePlane.drawable = New!ShapePlane(8, 8, 2, assetManager);
        ePlane.material = mat2;
        
        environment.backgroundColor = Color4f(0.2f, 0.2f, 0.2f, 1.0f);
    }
    
    override void onRelease()
    {
        super.onRelease();
    }

    override void onKeyDown(int key)
    {
        if (key == KEY_ESCAPE)
            exitApplication();
    }
}

class MyApplication: SceneApplication
{
    this(string[] args)
    {
        super(1280, 720, "Dagon (OpenGL 3.3)", args);

        TestScene test = New!TestScene(sceneManager);
        sceneManager.addScene(test, "TestScene");

        sceneManager.goToScene("TestScene");
    }
}

void main(string[] args)
{
    writeln("Allocated memory at start: ", allocatedMemory);
    MyApplication app = New!MyApplication(args);
    app.run();
    Delete(app);
    writeln("Allocated memory at end: ", allocatedMemory);
    //printMemoryLog();
}
