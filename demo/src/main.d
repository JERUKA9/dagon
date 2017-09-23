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

// Attach a light to Entity
class LightBehaviour: Behaviour
{
    LightSource light;

    this(Entity e, LightSource light)
    {
        super(e);
        
        this.light = light;
    }

    override void update(double dt)
    {
        light.position = entity.position;
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
    
    TextureAsset aTexCloud;
    
    OBJAsset aBuilding;
    OBJAsset aImrod;
    OBJAsset aSphere;
    
    IQMAsset iqm;
    
    Entity mrfixit;
    Actor actor;
    
    ClusteredLightManager clm;
    BlinnPhongClusteredBackend bpcb;
    ShadelessBackend shadeless;
    SkyBackend skyb;
    CloudBackend cloudb;
    CascadedShadowMap shadowMap;
    float rx = -45.0f;
    float ry = 0.0f;
    
    FirstPersonView fpview;
    
    Entity eSky;
    Entity eCloudPlane1;
    Entity eCloudPlane2;
    
    PhysicsWorld world;
    RigidBody bGround;
    Geometry gGround;
    float lightBallRadius = 0.5f;
    Geometry gLightBall;
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
        
        aTexCloud = addTextureAsset("data/textures/clouds.png");
        
        aBuilding = New!OBJAsset(assetManager);
        addAsset(aBuilding, "data/obj/castle.obj");
        
        aImrod = New!OBJAsset(assetManager);
        addAsset(aImrod, "data/obj/imrod.obj");
        
        aSphere = New!OBJAsset(assetManager);
        addAsset(aSphere, "data/obj/sphere.obj");
        
        assetManager.mountDirectory("data/iqm");
        iqm = New!IQMAsset(assetManager);
        addAsset(iqm, "data/iqm/mrfixit.iqm");
    }

    override void onAllocate()
    {
        super.onAllocate();
        
        fpview = New!FirstPersonView(eventManager, Vector3f(25.0f, 1.8f, 0.0f), assetManager);
        fpview.camera.turn = -90.0f;
        view = fpview;
        
        fb = New!Framebuffer(eventManager.windowWidth, eventManager.windowHeight, assetManager);
        fbAA = New!Framebuffer(eventManager.windowWidth, eventManager.windowHeight, assetManager);
        fxaa = New!PostFilterFXAA(fb, assetManager);
        lens = New!PostFilterLensDistortion(fbAA, assetManager);
        
        clm = New!ClusteredLightManager(view, 200.0f, 100, assetManager);
        bpcb = New!BlinnPhongClusteredBackend(clm, assetManager);
        shadeless = New!ShadelessBackend(assetManager);
        skyb = New!SkyBackend(assetManager);
        cloudb = New!CloudBackend(assetManager);
        
        shadowMap = New!CascadedShadowMap(1024, this, assetManager);
        defaultMaterialBackend.shadowMap = shadowMap;
        bpcb.shadowMap = shadowMap;
        
        auto matDefault = createMaterial(bpcb);
        
        auto matImrod = createMaterial(bpcb);
        matImrod.diffuse = aTexImrodDiffuse.texture;
        matImrod.normal = aTexImrodNormal.texture;

        auto mStone = createMaterial(bpcb);
        mStone.diffuse = aTexStoneDiffuse.texture;
        mStone.normal = aTexStoneNormal.texture;
        mStone.height = aTexStoneHeight.texture;
        mStone.roughness = 0.2f;
        mStone.parallax = ParallaxSimple; //ParallaxOcclusionMapping;
        
        auto mGround = createMaterial(bpcb);
        mGround.diffuse = aTexStone2Diffuse.texture;
        mGround.normal = aTexStone2Normal.texture;
        mGround.height = aTexStone2Height.texture;
        mGround.roughness = 0.2f;
        mGround.parallax = ParallaxSimple;
        
        auto matSky = createMaterial(skyb);
        
        auto matCloud1 = createMaterial(cloudb);
        matCloud1.diffuse = aTexCloud.texture;
        matCloud1.timeScale = 0.005;
        
        auto matCloud2 = createMaterial(cloudb);
        matCloud2.diffuse = aTexCloud.texture;
        matCloud2.timeScale = 0.01;
        
        eSky = createEntity3D();
        eSky.material = matSky;
        eSky.drawable = aSphere.mesh;
        eSky.scaling = Vector3f(100.0f, 100.0f, 100.0f);
        eSky.castShadow = false;
        
        eCloudPlane1 = createEntity3D();
        eCloudPlane1.drawable = New!ShapePlane(2000, 2000, 10, assetManager);
        eCloudPlane1.material = matCloud1;
        eCloudPlane1.rotation = rotationQuaternion(Axis.x, degtorad(180.0f));
        eCloudPlane1.position.y = 60.0f;
        eCloudPlane1.castShadow = false;
        
        eCloudPlane2 = createEntity3D();
        eCloudPlane2.drawable = New!ShapePlane(2000, 2000, 5, assetManager);
        eCloudPlane2.material = matCloud2;
        eCloudPlane2.rotation = rotationQuaternion(Axis.x, degtorad(180.0f));
        eCloudPlane2.position.y = 50.0f;
        eCloudPlane2.castShadow = false;

        Entity eBuilding = createEntity3D();
        eBuilding.drawable = aBuilding.mesh;
        eBuilding.material = mStone;
        
        Entity eImrod = createEntity3D();
        eImrod.material = matImrod;
        eImrod.drawable = aImrod.mesh;
        eImrod.position.x = -2.0f;
        eImrod.scaling = Vector3f(0.5, 0.5, 0.5);
        
        actor = New!Actor(iqm.model, assetManager);
        mrfixit = createEntity3D();
        mrfixit.drawable = actor;
        mrfixit.material = matDefault;
        mrfixit.position.x = 2.0f;
        mrfixit.rotation = rotationQuaternion(Axis.y, degtorad(-90.0f));
        mrfixit.scaling = Vector3f(0.25, 0.25, 0.25);
        mrfixit.defaultController.swapZY = true;
        
        world = New!PhysicsWorld();

        bvh = meshBVH(aBuilding.mesh);
        world.bvhRoot = bvh.root;
        
        RigidBody bGround = world.addStaticBody(Vector3f(0.0f, 0.0f, 0.0f));
        gGround = New!GeomBox(Vector3f(100.0f, 1.0f, 100.0f));
        world.addShapeComponent(bGround, gGround, Vector3f(0.0f, -1.0f, 0.0f), 1.0f);
        auto eGround = createEntity3D();
        eGround.drawable = New!ShapePlane(200, 200, 100, assetManager);
        eGround.material = mGround;

        gLightBall = New!GeomSphere(lightBallRadius);
        
        gSphere = New!GeomEllipsoid(Vector3f(0.9f, 1.0f, 0.9f));
        gSensor = New!GeomBox(Vector3f(0.5f, 0.5f, 0.5f));
        character = New!CharacterController(world, fpview.camera.position, 80.0f, gSphere, assetManager);
        character.createSensor(gSensor, Vector3f(0.0f, -0.75f, 0.0f));
        
        auto text = New!TextLine(aFont.font, "Press <LMB> to switch mouse look, WASD to move, spacebar to jump, <RMB> to create a light, arrow keys to rotate the sun", assetManager);
        text.color = Color4f(1.0f, 1.0f, 1.0f, 0.7f);
        
        auto eText = createEntity2D();
        eText.drawable = text;
        eText.position = Vector3f(16.0f, eventManager.windowHeight - 30.0f, 0.0f);
        
        text2 = New!TextLine(aFont.font, "0", assetManager);
        text2.color = Color4f(1.0f, 1.0f, 1.0f, 0.7f);
        
        auto eText2 = createEntity2D();
        eText2.drawable = text2;
        eText2.position = Vector3f(16.0f, eventManager.windowHeight - 50.0f, 0.0f);
        
        environment.useSkyColors = true;
        environment.atmosphericFog = true;
        
        initializedPhysics = true;
    }
    
    TextLine text2;
    
    override void onStart()
    {
        super.onStart();
        actor.play();
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
            Vector3f pos = fpview.camera.position + fpview.camera.characterMatrix.forward * -2.0f;
            Color4f color = lightColors[uniform(0, 9)];
            
            auto light = clm.addLight(pos, color, 3.0f, lightBallRadius);
            
            if (light)
            {
                auto mLightBall = createMaterial(shadeless);
                mLightBall.diffuse = color;
                
                auto eLightBall = createEntity3D();
                eLightBall.drawable = aSphere.mesh;
                eLightBall.scaling = Vector3f(-lightBallRadius, -lightBallRadius, -lightBallRadius);
                eLightBall.castShadow = false;
                eLightBall.material = mLightBall;
                eLightBall.position = pos;
                auto bLightBall = world.addDynamicBody(Vector3f(0, 0, 0), 0.0f);
                RigidBodyController rbc = New!RigidBodyController(eLightBall, bLightBall);
                eLightBall.controller = rbc;
                world.addShapeComponent(bLightBall, gLightBall, Vector3f(0.0f, 0.0f, 0.0f), 10.0f);
                
                LightBehaviour lc = New!LightBehaviour(eLightBall, light);
            }
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
        
        eSky.position = fpview.camera.position;
        eCloudPlane1.position = fpview.camera.position + Vector3f(0, 80, 0);
        eCloudPlane2.position = fpview.camera.position + Vector3f(0, 50, 0);
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
        
        Frustum frustum;
        Matrix4x4f mvp = rc3d.projectionMatrix * rc3d.viewMatrix;
        frustum.fromMVP(mvp);
        clm.update(frustum);

        uint n = sprintf(lightsText.ptr, "FPS: %u | visible lights: %u | total lights: %u | max visible lights: %u", eventManager.fps, clm.currentlyVisibleLights, clm.lightSources.length, clm.maxNumLights);
        string s = cast(string)lightsText[0..n];
        text2.setText(s);
    }
    
    char[100] lightsText;
    
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
            Delete(gLightBall);
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
        super(1280, 720, false, "Dagon (OpenGL 3.3)", args);

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
