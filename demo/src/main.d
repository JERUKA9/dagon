module main;

import std.stdio;
import std.random;

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
    
    TextureAsset aTexCrateDiffuse;
    
    OBJAsset aBuilding;
    OBJAsset aImrod;
    OBJAsset aCrate;
    
    ClusteredLightManager clm;
    BlinnPhongClusteredBackend bpcb;
    CascadedShadowMap shadowMap;
    float rx = -45.0f;
    float ry = 0.0f;
    
    FirstPersonView fpview;
    
    PhysicsWorld world;
    RigidBody bGround;
    Geometry gGround;
    Geometry gCrate;
    GeomEllipsoid gSphere;
    GeomBox gSensor;
    CharacterController character;
    BVHTree!Triangle bvh;
    bool initializedPhysics = false;
    
    Framebuffer fb;
    Framebuffer fbAA;
    PostFilterFXAA fxaa;
    PostFilterLensDistortion lens;

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
        
        aTexCrateDiffuse = addTextureAsset("data/textures/crate.png");
        
        aBuilding = New!OBJAsset(assetManager);
        addAsset(aBuilding, "data/obj/level.obj");
        
        aImrod = New!OBJAsset(assetManager);
        addAsset(aImrod, "data/obj/imrod.obj");
        
        aCrate = New!OBJAsset(assetManager);
        addAsset(aCrate, "data/obj/crate.obj");
    }

    override void onAllocate()
    {
        super.onAllocate();
        
        fpview = New!FirstPersonView(eventManager, Vector3f(15.0f, 1.8f, 0.0f), assetManager);
        fpview.camera.turn = -90.0f;
        view = fpview;
        
        fb = New!Framebuffer(eventManager.windowWidth, eventManager.windowHeight, assetManager);
        fbAA = New!Framebuffer(eventManager.windowWidth, eventManager.windowHeight, assetManager);
        fxaa = New!PostFilterFXAA(fb, assetManager);
        lens = New!PostFilterLensDistortion(fbAA, assetManager);
        
        clm = New!ClusteredLightManager(view, assetManager);
        bpcb = New!BlinnPhongClusteredBackend(clm, assetManager);
        
        shadowMap = New!CascadedShadowMap(1024, this, assetManager);
        defaultMaterialBackend.shadowMap = shadowMap;
        bpcb.shadowMap = shadowMap;
        
        auto matImrod = createMaterial(bpcb);
        matImrod.diffuse = aTexImrodDiffuse.texture;
        matImrod.normal = aTexImrodNormal.texture;
        
        auto mCrate = createMaterial(bpcb);
        mCrate.diffuse = aTexCrateDiffuse.texture;
        mCrate.roughness = 0.9f;
        
        auto mStone = createMaterial(bpcb);
        mStone.diffuse = aTexStoneDiffuse.texture;
        mStone.normal = aTexStoneNormal.texture;
        mStone.height = aTexStoneHeight.texture;
        mStone.roughness = 0.2f;
        mStone.parallax = ParallaxOcclusionMapping;
        
        auto mGround = createMaterial(bpcb);
        mGround.diffuse = aTexStone2Diffuse.texture;
        mGround.normal = aTexStone2Normal.texture;
        mGround.height = aTexStone2Height.texture;
        mGround.roughness = 0.8f;
        mGround.parallax = ParallaxSimple;
        
        Entity eBuilding = createEntity3D();
        eBuilding.drawable = aBuilding.mesh;
        eBuilding.material = mStone;
        
        Entity eImrod = createEntity3D();
        eImrod.material = matImrod;
        eImrod.drawable = aImrod.mesh;
        eImrod.position.x = 10.0f;
        eImrod.position.y = 0.8f;
        eImrod.scaling = Vector3f(0.5, 0.5, 0.5);
        
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

        gCrate = New!GeomBox(Vector3f(1.0f, 1.0f, 1.0f));

        foreach(i; 0..5)
        {
            auto eCrate = createEntity3D();
            eCrate.drawable = aCrate.mesh;
            eCrate.material = mCrate;
            eCrate.position = Vector3f(i * 0.1f, 3.0f + 3.0f * cast(float)i, -5.0f);
            auto bCrate = world.addDynamicBody(Vector3f(0, 0, 0), 0.0f);
            RigidBodyController rbc = New!RigidBodyController(eCrate, bCrate);
            eCrate.controller = rbc;
            world.addShapeComponent(bCrate, gCrate, Vector3f(0.0f, 0.0f, 0.0f), 10.0f);
        }

        gSphere = New!GeomEllipsoid(Vector3f(0.9f, 1.0f, 0.9f));
        gSensor = New!GeomBox(Vector3f(0.5f, 0.5f, 0.5f));
        character = New!CharacterController(world, fpview.camera.position, 80.0f, gSphere, assetManager);
        character.createSensor(gSensor, Vector3f(0.0f, -0.75f, 0.0f));
        
        auto text = New!TextLine(aFont.font, "Press <LMB> to switch mouse look, WASD to move, spacebar to jump, arrow keys to rotate the sun", assetManager);
        text.color = Color4f(1.0f, 1.0f, 1.0f, 0.7f);
        
        auto eText = createEntity2D();
        eText.drawable = text;
        eText.position = Vector3f(16.0f, eventManager.windowHeight - 30.0f, 0.0f);
        
        environment.useSkyColors = true;
        
        initializedPhysics = true;
    }
    
    Color4f[9] lightColors = [
        Color4f(1, 1, 1, 1),
        Color4f(1, 0, 0, 1),
        Color4f(1, 0.5, 0, 1),
        Color4f(1, 1, 0, 1),
        Color4f(0, 1, 0, 1),
        Color4f(0, 1, 0.5, 1),
        Color4f(0, 1, 1, 1),
        Color4f(0, 0.5, 1, 1),
        Color4f(0, 0, 1, 1)
    ];
    
    override void onMouseButtonDown(int button)
    {
        if (button == MB_LEFT)
        {
            if (fpview.active)
                fpview.active = false;
            else
                fpview.active = true;
        }
        
        if (button == MB_RIGHT)
        {
            clm.addLight(fpview.camera.position, lightColors[uniform(0, 9)] * 2.0f, uniform(2.0f, 5.0f));
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
        if (eventManager.keyPressed[KEY_DOWN]) rx += 30.0f * dt;
        if (eventManager.keyPressed[KEY_UP]) rx -= 30.0f * dt;
        if (eventManager.keyPressed[KEY_LEFT]) ry += 30.0f * dt;
        if (eventManager.keyPressed[KEY_RIGHT]) ry -= 30.0f * dt;
        environment.sunRotation = rotationQuaternion(Axis.y, degtorad(ry)) * rotationQuaternion(Axis.x, degtorad(rx));
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
        
        clm.update(dt);
    }
    
    override void onRender()
    {
        shadowMap.render(&rc3d);
        
        // Render 3D objects to fb
        fb.bind();
        prepareRender();        
        renderEntities3D(&rc3d);
        fb.unbind();
        
        // Render fxaa quad to fbAA
        fbAA.bind();
        prepareRender();
        fxaa.render(&rc2d);
        fbAA.unbind();
        
        // Render lens distortion quad 
        // and 2D objects to main framebuffer
        prepareRender();
        lens.render(&rc2d);
        renderEntities2D(&rc2d);
    }
    
    override void onRelease()
    {
        super.onRelease();
        
        if (initializedPhysics)
        {
            Delete(world);
            Delete(gGround);
            Delete(gCrate);
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
