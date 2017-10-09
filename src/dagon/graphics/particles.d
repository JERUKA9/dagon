module dagon.graphics.particles;

import std.random;

import dlib.core.memory;
import dlib.math.vector;
import dlib.math.matrix;
import dlib.math.transformation;
import dlib.math.interpolation;
import dlib.image.color;

import derelict.opengl.gl;
import dagon.logics.behaviour;
import dagon.logics.entity;
import dagon.graphics.texture;
import dagon.graphics.view;
import dagon.graphics.rc;
import dagon.graphics.material;
import dagon.graphics.mesh;

struct Particle
{
    Color4f startColor;
    Color4f color;
    Vector3f position;
    Vector3f acceleration;
    Vector3f velocity;
    Vector3f gravityVector;
    Vector2f scale;
    float lifetime;
    float time;
    bool move;
}

class ParticleSystem: Behaviour
{
    Particle[] particles;
    
    View view;
    
    float airFrictionDamping = 0.98f;
    
    float minLifetime = 1.0f;
    float maxLifetime = 3.0f;
    
    float minSize = 0.25f;
    float maxSize = 1.0f;
    
    float initialPositionRandomRadius = 0.0f;
    
    float minInitialSpeed = 1.0f;
    float maxInitialSpeed = 5.0f;
    
    Vector3f initialDirection = Vector3f(0, 1, 0);
    float initialDirectionRandomFactor = 1.0f;
    
    Color4f startColor = Color4f(1, 0.5f, 0, 1);
    Color4f endColor = Color4f(1, 1, 1, 0);
    
    bool haveParticlesToDraw = false;
    
    Vector3f[4] vertices;
    Vector2f[4] texcoords;
    uint[3][2] indices;
    
    GLuint vao = 0;
    GLuint vbo = 0;
    GLuint tbo = 0;
    GLuint eao = 0;
    
    Matrix4x4f invViewMatRot;
    
    Material material;

    this(Entity e, uint numParticles, View v)
    {
        super(e);
        
        view = v;
        
        particles = New!(Particle[])(numParticles);
        foreach(ref p; particles)
        {
            resetParticle(p);
        }
        
        vertices[0] = Vector3f(0, 1, 0);
        vertices[1] = Vector3f(0, 0, 0);
        vertices[2] = Vector3f(1, 0, 0);
        vertices[3] = Vector3f(1, 1, 0);
        
        texcoords[0] = Vector2f(0, 0);
        texcoords[1] = Vector2f(0, 1);
        texcoords[2] = Vector2f(1, 1);
        texcoords[3] = Vector2f(1, 0);
        
        indices[0][0] = 0;
        indices[0][1] = 1;
        indices[0][2] = 2;
        
        indices[1][0] = 0;
        indices[1][1] = 2;
        indices[1][2] = 3;
        
        glGenBuffers(1, &vbo);
        glBindBuffer(GL_ARRAY_BUFFER, vbo);
        glBufferData(GL_ARRAY_BUFFER, vertices.length * float.sizeof * 3, vertices.ptr, GL_STATIC_DRAW); 

        glGenBuffers(1, &tbo);
        glBindBuffer(GL_ARRAY_BUFFER, tbo);
        glBufferData(GL_ARRAY_BUFFER, texcoords.length * float.sizeof * 2, texcoords.ptr, GL_STATIC_DRAW);

        glGenBuffers(1, &eao);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, eao);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, indices.length * uint.sizeof * 3, indices.ptr, GL_STATIC_DRAW);

        glGenVertexArrays(1, &vao);
        glBindVertexArray(vao);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, eao);
    
        glEnableVertexAttribArray(VertexAttrib.Vertices);
        glBindBuffer(GL_ARRAY_BUFFER, vbo);
        glVertexAttribPointer(VertexAttrib.Vertices, 3, GL_FLOAT, GL_FALSE, 0, null);
    
        glEnableVertexAttribArray(VertexAttrib.Texcoords);
        glBindBuffer(GL_ARRAY_BUFFER, tbo);
        glVertexAttribPointer(VertexAttrib.Texcoords, 2, GL_FLOAT, GL_FALSE, 0, null);

        glBindVertexArray(0);
    }

    ~this()
    {
        Delete(particles);
        //forceFields.free();
    }

    void resetParticle(ref Particle p)
    {
        if (initialPositionRandomRadius > 0.0f)
        {
            float randomDist = uniform(0.0f, initialPositionRandomRadius);
            p.position = entity.position + randomUnitVector3!float * randomDist;
        }
        else
            p.position = entity.position;
        Vector3f r = randomUnitVector3!float;
        float initialSpeed = uniform(minInitialSpeed, maxInitialSpeed);
        p.velocity = lerp(initialDirection, r, initialDirectionRandomFactor) * initialSpeed;
        p.lifetime = uniform(minLifetime, maxLifetime);
        p.gravityVector = Vector3f(0, -1, 0);
        float s = uniform(minSize, maxSize);
        p.scale = Vector2f(s, s);
        p.time = 0.0f;
        p.move = true;
        p.startColor = startColor;
        p.color = p.startColor;
    }
    
    override void update(double dt)
    {
        invViewMatRot = matrix3x3to4x4(matrix4x4to3x3(view.invViewMatrix));

        haveParticlesToDraw = false;
        foreach(ref p; particles)
        if (p.time < p.lifetime)
        {
            p.time += dt;
            if (p.move)
            {
                p.acceleration = Vector3f(0, 0, 0);
                
                /*
                foreach(ref ff; forceFields)
                {
                    ff.affect(p);
                }
                */
                
                p.velocity += p.acceleration * dt;
                p.velocity = p.velocity * airFrictionDamping;

                p.position += p.velocity * dt;
            }

            float t = p.time / p.lifetime;
            p.color.a = lerp(1.0f, 0.0f, t);

            haveParticlesToDraw = true;
        }
        else
            resetParticle(p);
    }
    
    override void render(RenderingContext* rc)
    {        
        if (haveParticlesToDraw)
        {
            glEnable(GL_BLEND);
            glBlendFunc(GL_SRC_ALPHA, GL_ONE);
            glDepthMask(GL_FALSE);
            glDisable(GL_CULL_FACE);
            
            foreach(ref p; particles)
            if (p.time < p.lifetime)
            {
                Matrix4x4f modelViewMatrix = 
                    view.viewMatrix * 
                    translationMatrix(p.position) * 
                    invViewMatRot * 
                    scaleMatrix(Vector3f(p.scale.x, p.scale.y, 1.0f));
                
                RenderingContext rcLocal = *rc;
                rcLocal.modelViewMatrix = modelViewMatrix;

                if (material)
                    material.bind(&rcLocal);
        
                glBindVertexArray(vao);
                glDrawElements(GL_TRIANGLES, cast(uint)indices.length * 3, GL_UNSIGNED_INT, cast(void*)0);
                glBindVertexArray(0);
        
                if (material)
                    material.unbind();
            }
            
            glEnable(GL_CULL_FACE);
            glDepthMask(GL_TRUE);
            glDisable(GL_BLEND);
        }
    }
}
