module main;

import std.stdio;

import dagon;

import dmech.world;
import dmech.geometry;
import dmech.rigidbody;
import dmech.bvh;

import rigidbodycontroller;
import character;

BVHTree!Triangle meshBVH(Mesh mesh)
{
    DynamicArray!Triangle tris;

    foreach(tri; mesh)
    {
        Triangle tri2 = tri;
        tri2.v[0] = tri.v[0];
        tri2.v[1] = tri.v[1];
        tri2.v[2] = tri.v[2];
        tri2.normal = tri.normal;
        tri2.barycenter = (tri2.v[0] + tri2.v[1] + tri2.v[2]) / 3;
        tris.append(tri2);
    }

    assert(tris.length);
    BVHTree!Triangle bvh = New!(BVHTree!Triangle)(tris, 4);
    tris.free();
    return bvh;
}

class BlinnPhongBackend: GLSLMaterialBackend
{
    string vsText = 
    q{
        #version 330 core
        
        uniform mat4 modelViewMatrix;
        uniform mat4 normalMatrix;
        uniform mat4 projectionMatrix;
        
        uniform mat4 shadowMatrix1;
        uniform mat4 shadowMatrix2;
        uniform mat4 shadowMatrix3;
        
        layout (location = 0) in vec3 va_Vertex;
        layout (location = 1) in vec3 va_Normal;
        layout (location = 2) in vec2 va_Texcoord;
        
        out vec3 eyePosition;
        out vec3 eyeNormal;
        out vec2 texCoord;
        
        out vec4 shadowCoord1;
        out vec4 shadowCoord2;
        out vec4 shadowCoord3;
        
        const float eyeSpaceNormalShift = 0.05;
        
        void main()
        {
            texCoord = va_Texcoord;
            eyeNormal = (normalMatrix * vec4(va_Normal, 0.0)).xyz;
            vec4 pos = modelViewMatrix * vec4(va_Vertex, 1.0);
            eyePosition = pos.xyz;
            
            vec4 posShifted = pos + vec4(eyeNormal * eyeSpaceNormalShift, 0.0);
            shadowCoord1 = shadowMatrix1 * posShifted;
            shadowCoord2 = shadowMatrix2 * posShifted;
            shadowCoord3 = shadowMatrix3 * posShifted;
            
            gl_Position = projectionMatrix * pos;
        }
    };

    string fsText =
    q{
        #version 330 core
        
        uniform mat4 viewMatrix;
        uniform sampler2D diffuseTexture;
        uniform sampler2D normalTexture;
        uniform sampler2D heightTexture;
        
        uniform float roughness;
        
        uniform float parallaxScale;
        uniform float parallaxBias;
        
        uniform sampler2DArrayShadow shadowTextureArray;
        uniform float shadowTextureSize;
        uniform bool useShadows;
        
        uniform vec3 sunDirection;
        uniform vec3 sunColor;
        
        in vec3 eyePosition;
        in vec3 eyeNormal;
        in vec2 texCoord;
        
        in vec4 shadowCoord1;
        in vec4 shadowCoord2;
        in vec4 shadowCoord3;
        
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
        
        float shadowLookup(sampler2DArrayShadow depths, float layer, vec4 coord, vec2 offset)
        {
            float texelSize = 1.0 / shadowTextureSize;
            vec2 v = offset * texelSize * coord.w;
            vec4 c = (coord + vec4(v.x, v.y, 0.0, 0.0)) / coord.w;
            c.w = c.z;
            c.z = layer;
            float s = texture(depths, c);
            return s;
        }
        
        float pcf(sampler2DArrayShadow depths, float layer, vec4 coord, float radius, float yshift)
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
        
        float weight(vec4 tc)
        {
            vec2 proj = vec2(tc.x / tc.w, tc.y / tc.w);
            proj = (1.0 - abs(proj * 2.0 - 1.0)) * 8.0;
            proj = clamp(proj, 0.0, 1.0);
            return min(proj.x, proj.y);
        }
        
        void main()
        {
            vec3 L = (viewMatrix * lightPos).xyz;
            L = normalize(L - eyePosition);
                        
            vec3 N = normalize(eyeNormal);
            vec3 E = normalize(-eyePosition);
            
            mat3 TBN = cotangentFrame(eyeNormal, eyePosition, texCoord);
            
            float height = texture2D(heightTexture, texCoord).r;
            height = height * parallaxScale + parallaxBias;
            vec3 Ee = normalize(E * TBN);
            vec2 shiftedTexCoord = texCoord + (height * Ee.xy);
            
            vec3 tN = normalize(texture2D(normalTexture, shiftedTexCoord).rgb * 2.0 - 1.0);
            tN.y = -tN.y;
            N = normalize(TBN * tN);

            float gloss = 1.0 - roughness;
            float shininess = gloss * 128.0;
            
            // TODO: read ambient params from uniforms
            const float ambient = 0.1;
            
            float sunDiffBrightness = clamp(dot(N, sunDirection), 0.0, 1.0);
            vec3 halfEye = normalize(sunDirection + E);
            float NH = dot(N, halfEye);
            float sunSpecBrightness = pow(max(NH, 0.0), shininess) * gloss;
            
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
            
            vec4 diffuseColor = texture(diffuseTexture, shiftedTexCoord);
            vec3 objColor = diffuseColor.rgb * (vec3(ambient) + sunColor * sunDiffBrightness * (1.0 - ambient) * s1) + sunColor * sunSpecBrightness * s1;
            frag_color = vec4(objColor, 1.0);
        }
    };
    
    override string vertexShaderSrc() {return vsText;}
    override string fragmentShaderSrc() {return fsText;}

    GLint viewMatrixLoc;
    GLint modelViewMatrixLoc;
    GLint projectionMatrixLoc;
    GLint normalMatrixLoc;
    
    GLint shadowMatrix1Loc;
    GLint shadowMatrix2Loc; 
    GLint shadowMatrix3Loc;
    GLint shadowTextureArrayLoc;
    GLint shadowTextureSizeLoc;
    GLint useShadowsLoc;
    
    GLint roughnessLoc;
    
    GLint parallaxScaleLoc;
    GLint parallaxBiasLoc;
    
    GLint diffuseTextureLoc;
    GLint normalTextureLoc;
    GLint heightTextureLoc;
    
    GLint sunDirectionLoc;
    GLint sunColorLoc;
    
    CascadedShadowMap shadowMap;
    Matrix4x4f defaultShadowMat;
    Vector3f defaultLightDir;
    
    this(Owner o)
    {
        super(o);

        viewMatrixLoc = glGetUniformLocation(shaderProgram, "viewMatrix");
        modelViewMatrixLoc = glGetUniformLocation(shaderProgram, "modelViewMatrix");
        projectionMatrixLoc = glGetUniformLocation(shaderProgram, "projectionMatrix");
        normalMatrixLoc = glGetUniformLocation(shaderProgram, "normalMatrix");
        
        shadowMatrix1Loc = glGetUniformLocation(shaderProgram, "shadowMatrix1");
        shadowMatrix2Loc = glGetUniformLocation(shaderProgram, "shadowMatrix2");
        shadowMatrix3Loc = glGetUniformLocation(shaderProgram, "shadowMatrix3");
        shadowTextureArrayLoc = glGetUniformLocation(shaderProgram, "shadowTextureArray");
        shadowTextureSizeLoc = glGetUniformLocation(shaderProgram, "shadowTextureSize");
        useShadowsLoc = glGetUniformLocation(shaderProgram, "useShadows");
        
        roughnessLoc = glGetUniformLocation(shaderProgram, "roughness"); 
       
        parallaxScaleLoc = glGetUniformLocation(shaderProgram, "parallaxScale");
        parallaxBiasLoc = glGetUniformLocation(shaderProgram, "parallaxBias");
        
        diffuseTextureLoc = glGetUniformLocation(shaderProgram, "diffuseTexture");
        normalTextureLoc = glGetUniformLocation(shaderProgram, "normalTexture");
        heightTextureLoc = glGetUniformLocation(shaderProgram, "heightTexture");
        
        sunDirectionLoc = glGetUniformLocation(shaderProgram, "sunDirection");
        sunColorLoc = glGetUniformLocation(shaderProgram, "sunColor");
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
        auto iheight = "height" in mat.inputs;
        auto iroughness = "roughness" in mat.inputs;
        bool shadowsEnabled = boolProp(mat, "shadowsEnabled");
        
        glEnable(GL_CULL_FACE);
        
        glUseProgram(shaderProgram);
        
        // Matrices
        glUniformMatrix4fv(viewMatrixLoc, 1, GL_FALSE, rc.viewMatrix.arrayof.ptr);
        glUniformMatrix4fv(modelViewMatrixLoc, 1, GL_FALSE, rc.modelViewMatrix.arrayof.ptr);
        glUniformMatrix4fv(projectionMatrixLoc, 1, GL_FALSE, rc.projectionMatrix.arrayof.ptr);
        glUniformMatrix4fv(normalMatrixLoc, 1, GL_FALSE, rc.normalMatrix.arrayof.ptr);
        
        // Environment parameters
        Vector4f sunHGVector = Vector4f(0.0f, 1.0f, 0.0, 0.0f);
        Vector3f sunColor = Vector3f(1.0f, 1.0f, 1.0f);
        if (rc.environment)
        {
            sunHGVector = Vector4f(rc.environment.sunDirection);
            sunHGVector.w = 0.0;
            sunColor = rc.environment.sunColor;
        }
        Vector3f sunDirectionEye = sunHGVector * rc.viewMatrix;
        glUniform3fv(sunDirectionLoc, 1, sunDirectionEye.arrayof.ptr);
        glUniform3fv(sunColorLoc, 1, sunColor.arrayof.ptr);
        
        // PBR parameters
        glUniform1f(roughnessLoc, iroughness.asFloat);
        
        // Parallax mapping parameters
        float parallaxScale = 0.0f;
        float parallaxBias = 0.0f;
        if (iheight.texture is null)
        {
            Color4f color = Color4f(0.3, 0.3, 0.3, 0);
            iheight.texture = makeOnePixelTexture(mat, color);
        }
        else
        {
            parallaxScale = 0.03f;
            parallaxBias = -0.01f;
        }
        glUniform1f(parallaxScaleLoc, parallaxScale);
        glUniform1f(parallaxBiasLoc, parallaxBias);
        
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
        
        // Texture 2 - height map
        // TODO: pass height data as an alpha channel of normap map, 
        // thus releasing space for some additional texture
        glActiveTexture(GL_TEXTURE2);
        iheight.texture.bind();
        glUniform1i(heightTextureLoc, 2);
        
        // Texture 3 - shadow map cascades (3 layer texture array)
        if (shadowMap && shadowsEnabled)
        {
            glActiveTexture(GL_TEXTURE3);
            glBindTexture(GL_TEXTURE_2D_ARRAY, shadowMap.depthTexture);

            glUniform1i(shadowTextureArrayLoc, 3);
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
        
        glActiveTexture(GL_TEXTURE0);
    }
    
    override void unbind(GenericMaterial mat)
    {
        auto idiffuse = "diffuse" in mat.inputs;
        auto inormal = "normal" in mat.inputs;
        auto iheight = "height" in mat.inputs;
        
        glActiveTexture(GL_TEXTURE0);
        idiffuse.texture.unbind();
        
        glActiveTexture(GL_TEXTURE1);
        inormal.texture.unbind();
        
        glActiveTexture(GL_TEXTURE2);
        iheight.texture.unbind();
        
        glActiveTexture(GL_TEXTURE3);
        glBindTexture(GL_TEXTURE_2D_ARRAY, 0);
        
        glActiveTexture(GL_TEXTURE0);
        
        glUseProgram(0);
    }
}

class TestScene: BaseScene3D
{
    FontAsset aFont;

    TextureAsset aTexImrodDiffuse;
    TextureAsset aTexImrodNormal;
    
    TextureAsset aTexStoneDiffuse;
    TextureAsset aTexStoneNormal;
    TextureAsset aTexStoneHeight;
    
    TextureAsset aTexStone2Diffuse;
    TextureAsset aTexStone2Normal;
    TextureAsset aTexStone2Height;
    
    OBJAsset aBuilding;
    
    BlinnPhongBackend bpb;
    
    CascadedShadowMap shadowMap;
    float r = -45.0f;
    float ry = 0.0f;
    
    FirstPersonView fpview;
    
    PhysicsWorld world;
    RigidBody bGround;
    Geometry gGround;
    //Geometry gCrate;
    GeomEllipsoid gSphere;
    GeomBox gSensor;
    CharacterController character;
    BVHTree!Triangle bvh;
    bool initializedPhysics = false;

    this(SceneManager smngr)
    {
        super(smngr);
    }

    override void onAssetsRequest()
    {
        aFont = addFontAsset("data/font/DroidSans.ttf", 14);
    
        aTexImrodDiffuse = addTextureAsset("data/obj/imrod-diffuse.png");
        aTexImrodNormal = addTextureAsset("data/obj/imrod-normal.png");
        
        aTexStoneDiffuse = addTextureAsset("data/textures/stone-albedo.png");
        aTexStoneNormal = addTextureAsset("data/textures/stone-normal.png");
        aTexStoneHeight = addTextureAsset("data/textures/stone-height.png");
        
        aTexStone2Diffuse = addTextureAsset("data/textures/stone2-albedo.png");
        aTexStone2Normal = addTextureAsset("data/textures/stone2-normal.png");
        aTexStone2Height = addTextureAsset("data/textures/stone2-height.png");
        
        aBuilding = New!OBJAsset(assetManager);
        addAsset(aBuilding, "data/obj/level.obj");
    }

    override void onAllocate()
    {
        super.onAllocate();
        
        fpview = New!FirstPersonView(eventManager, Vector3f(10.0f, 1.8f, 0.0f), assetManager);
        fpview.camera.turn = -90.0f;
        view = fpview;
        
        shadowMap = New!CascadedShadowMap(1024, this, assetManager);
        
        bpb = New!BlinnPhongBackend(assetManager);
        bpb.shadowMap = shadowMap;
        
        auto mat1 = New!GenericMaterial(bpb, assetManager);
        mat1.diffuse = aTexImrodDiffuse.texture;
        mat1.normal = aTexImrodNormal.texture;
        
        auto mStone = New!GenericMaterial(bpb, assetManager);
        mStone.diffuse = aTexStoneDiffuse.texture;
        mStone.normal = aTexStoneNormal.texture;
        mStone.height = aTexStoneHeight.texture;
        mStone.roughness = 0.2f;
        
        auto mGround = New!GenericMaterial(bpb, assetManager);
        mGround.diffuse = aTexStone2Diffuse.texture;
        mGround.normal = aTexStone2Normal.texture;
        mGround.height = aTexStone2Height.texture;
        mGround.roughness = 0.8f;
        
        Entity eBuilding = createEntity3D();
        eBuilding.drawable = aBuilding.mesh;
        eBuilding.material = mStone;
        
        world = New!PhysicsWorld();

        bvh = meshBVH(aBuilding.mesh);
        world.bvhRoot = bvh.root;
        
        RigidBody bGround = world.addStaticBody(Vector3f(0.0f, 0.0f, 0.0f));
        gGround = New!GeomBox(Vector3f(100.0f, 0.8f, 100.0f));
        world.addShapeComponent(bGround, gGround, Vector3f(0.0f, 0.0f, 0.0f), 1.0f);
        auto eGround = createEntity3D();
        eGround.drawable = New!ShapePlane(200, 200, 100, assetManager);
        eGround.material = mGround;
        eGround.position.y = 0.8f;
        
        gSphere = New!GeomEllipsoid(Vector3f(0.9f, 1.0f, 0.9f));
        gSensor = New!GeomBox(Vector3f(0.5f, 0.5f, 0.5f));
        character = New!CharacterController(world, fpview.camera.position, 80.0f, gSphere, assetManager);
        character.createSensor(gSensor, Vector3f(0.0f, -0.75f, 0.0f));
        
        auto text = New!TextLine(aFont.font, "Hello, World! Привет, мир!", assetManager);
        text.color = Color4f(1.0f, 1.0f, 0.0f, 0.5f);
        
        auto eText = createEntity2D();
        eText.drawable = text;
        eText.position = Vector3f(16.0f, eventManager.windowHeight - 30.0f, 0.0f);
        
        environment.backgroundColor = Color4f(0.2f, 0.2f, 0.2f, 1.0f);
        
        initializedPhysics = true;
    }
    
    override void onMouseButtonDown(int button)
    {
        if (button == MB_LEFT)
        {
            if (fpview.active)
                fpview.active = false;
            else
                fpview.active = true;
        }
    }
    
    void updateCharacter(double dt)
    { 
        character.rotation.y = fpview.camera.turn;
        Vector3f forward = fpview.camera.characterMatrix.forward;
        Vector3f right = fpview.camera.characterMatrix.right; 
        float speed = 8.0f;
        Vector3f dir = Vector3f(0, 0, 0);
        if (eventManager.keyPressed[KEY_W]) dir += -forward;
        if (eventManager.keyPressed[KEY_S]) dir += forward;
        if (eventManager.keyPressed[KEY_A]) dir += -right;
        if (eventManager.keyPressed[KEY_D]) dir += right;
        character.move(dir.normalized, speed);
        if (eventManager.keyPressed[KEY_SPACE]) character.jump(2.0f);
        character.update();
    }
    
    void updateEnvironment(double dt)
    {
        if (eventManager.keyPressed[KEY_DOWN]) r += 30.0f * dt;
        if (eventManager.keyPressed[KEY_UP]) r -= 30.0f * dt;
        if (eventManager.keyPressed[KEY_LEFT]) ry += 30.0f * dt;
        if (eventManager.keyPressed[KEY_RIGHT]) ry -= 30.0f * dt;
        environment.sunRotation = rotationQuaternion(Axis.y, degtorad(ry)) * rotationQuaternion(Axis.x, degtorad(r));
    }
    
    void updateShadow(double dt)
    {
        shadowMap.position = fpview.camera.position;
        shadowMap.update(dt);
    }
    
    override void onLogicsUpdate(double dt)
    {  
        updateCharacter(dt);
        
        world.update(dt);
        fpview.camera.position = character.rbody.position;
        
        updateEnvironment(dt);
        updateShadow(dt);
    }
    
    override void onRender()
    {
        shadowMap.render(&rc3d);
       
        prepareRender();
        renderEntities3D(&rc3d);
        renderEntities2D(&rc2d);
    }
    
    override void onRelease()
    {
        super.onRelease();
        
        if (initializedPhysics)
        {
            Delete(world);
            Delete(gGround);
            //Delete(gCrate);
            Delete(gSphere);
            Delete(gSensor);
            bvh.free();
            initializedPhysics = false;
        }
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
}
