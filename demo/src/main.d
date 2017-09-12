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
        
        in vec3 eyePosition;
        in vec3 eyeNormal;
        in vec2 texCoord;
        
        out vec4 frag_color;
        
        const vec4 lightPos = vec4(0.0, 2.0, 0.0, 1.0);
        
        void main()
        {
            vec3 L = (viewMatrix * lightPos).xyz;
            L = normalize(L - eyePosition);
            vec3 N = normalize(eyeNormal);
            float diffuse = clamp(dot(L, N), 0.0, 1.0);
            frag_color = texture(diffuseTexture, texCoord) * diffuse;
        }
    };
    
    override string vertexShaderSrc() {return vsText;}
    override string fragmentShaderSrc() {return fsText;}

    GLint viewMatrixLoc;
    GLint modelViewMatrixLoc;
    GLint projectionMatrixLoc;
    GLint normalMatrixLoc;
    
    GLint diffuseTextureLoc;
    
    this(Owner o)
    {
        super(o);

        viewMatrixLoc = glGetUniformLocation(shaderProgram, "viewMatrix");
        modelViewMatrixLoc = glGetUniformLocation(shaderProgram, "modelViewMatrix");
        projectionMatrixLoc = glGetUniformLocation(shaderProgram, "projectionMatrix");
        normalMatrixLoc = glGetUniformLocation(shaderProgram, "normalMatrix");
        
        diffuseTextureLoc = glGetUniformLocation(shaderProgram, "diffuseTexture");
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
    }
    
    override void unbind(GenericMaterial mat)
    {
        auto idiffuse = "diffuse" in mat.inputs;
        
        glActiveTexture(GL_TEXTURE0);
        idiffuse.texture.unbind();
        
        glUseProgram(0);
    }
}

class TestScene: BaseScene3D
{
    TextureAsset aTexStoneDiffuse;
    
    SimpleBackend sb;

    this(SceneManager smngr)
    {
        super(smngr);
    }

    override void onAssetsRequest()
    {
        aTexStoneDiffuse = addTextureAsset("data/textures/stone-albedo.png");
    }

    override void onAllocate()
    {
        super.onAllocate();
        
        auto freeview = New!Freeview(eventManager, assetManager);
        freeview.setZoom(6.0f);
        view = freeview;
        
        sb = New!SimpleBackend(assetManager);
        
        auto mat = New!GenericMaterial(sb, assetManager);
        mat.diffuse = aTexStoneDiffuse.texture;
        
        Entity e = New!Entity(eventManager, assetManager);
        entities3D.append(e);
        //e.rotation = rotationQuaternion(Axis.x, degtorad(45.0f));
        e.drawable = New!ShapePlane(10, 10, 2, assetManager);
        e.material = mat;
        
        environment.backgroundColor = Color4f(0.5f, 0.5f, 0.5f, 1.0f);
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
        super(1280, 720, "Dagon", args);

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
