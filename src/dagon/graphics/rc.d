module dagon.graphics.rc;

import dlib.math.vector;
import dlib.math.matrix;
import dlib.math.transformation;
import dlib.geometry.frustum;
import derelict.opengl.gl;
import dagon.core.event;
import dagon.graphics.environment;
import dagon.graphics.material;

struct RenderingContext
{
    Vector3f position;
    Matrix3x3f rotation;
    Vector3f scaling;
    
    Matrix4x4f modelViewMatrix;

    Matrix4x4f modelMatrix;
    Matrix4x4f invModelMatrix;

    Vector3f cameraPosition;

    Matrix4x4f viewMatrix;
    Matrix4x4f invViewMatrix;

    Matrix4x4f projectionMatrix;
    Matrix4x4f normalMatrix;
    
    Frustum frustum;

    EventManager eventManager;
    Environment environment;
    Material overrideMaterial;
    
    float time;
    
    void init(EventManager emngr, Environment env)
    {
        position = Vector3f(0.0f, 0.0f, 0.0f);
        rotation = Matrix3x3f.identity;
        scaling = Vector3f(1.0f, 1.0f, 1.0f);
        modelViewMatrix = Matrix4x4f.identity;
        modelMatrix = Matrix4x4f.identity;
        invModelMatrix = Matrix4x4f.identity;
        cameraPosition = Vector3f(0.0f, 0.0f, 0.0f);
        viewMatrix = Matrix4x4f.identity;
        invViewMatrix = Matrix4x4f.identity;
        projectionMatrix = Matrix4x4f.identity;
        normalMatrix = Matrix4x4f.identity;
        eventManager = emngr;
        environment = env;
        overrideMaterial = null;
        time = 0.0f;
    }
    
    void init3D(EventManager emngr, Environment env, float fov, float znear, float zfar)
    {
        init(emngr, env);
        projectionMatrix = perspectiveMatrix(fov, emngr.aspectRatio, znear, zfar);
    }
    
    void init2D(EventManager emngr, Environment env, float znear, float zfar)
    {
        init(emngr, env);
        projectionMatrix = orthoMatrix(0.0f, emngr.windowWidth, 0.0f, emngr.windowHeight, znear, zfar);
    }
}

