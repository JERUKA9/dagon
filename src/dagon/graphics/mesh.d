module dagon.graphics.mesh;

import dlib.core.memory;
import dlib.geometry.triangle;
import dlib.math.vector;
import derelict.opengl.gl;
import dagon.core.interfaces;
import dagon.core.ownership;

enum VertexAttrib
{
    Vertices = 0,
    Normals = 1,
    Texcoords = 2
}

class Mesh: Owner, Drawable
{
    bool dataReady = false;
    bool canRender = false;
    
    Vector3f[] vertices;
    Vector3f[] normals;
    Vector2f[] texcoords;
    uint[3][] indices;
    
    GLuint vao = 0;
    GLuint vbo = 0;
    GLuint nbo = 0;
    GLuint tbo = 0;
    GLuint eao = 0;
    
    this(Owner o)
    {
        super(o);
    }
    
    ~this()
    {
        if (vertices.length) Delete(vertices);
        if (normals.length) Delete(normals);
        if (texcoords.length) Delete(texcoords);
        if (indices.length) Delete(indices);
        
        if (canRender)
        {
            glDeleteVertexArrays(1, &vao);
            glDeleteBuffers(1, &vbo);
            glDeleteBuffers(1, &nbo);
            glDeleteBuffers(1, &tbo);
            glDeleteBuffers(1, &eao);
        }
    }
    
    int opApply(scope int delegate(Triangle t) dg)
    {
        int result = 0;

        foreach(i, ref f; indices)
        {
            Triangle tri;

            tri.v[0] = vertices[f[0]];
            tri.v[1] = vertices[f[1]];
            tri.v[2] = vertices[f[2]];
            tri.n[0] = normals[f[0]];
            tri.n[1] = normals[f[1]];
            tri.n[2] = normals[f[2]];
            tri.t1[0] = texcoords[f[0]];
            tri.t1[1] = texcoords[f[1]];
            tri.t1[2] = texcoords[f[2]];
            tri.normal = (tri.n[0] + tri.n[1] + tri.n[2]) / 3.0f;

            result = dg(tri);
            if (result)
                break;
        }

        return result;
    }
    
    void prepareVAO()
    {
        if (!dataReady)
            return;

        glGenBuffers(1, &vbo);
        glBindBuffer(GL_ARRAY_BUFFER, vbo);
        glBufferData(GL_ARRAY_BUFFER, vertices.length * float.sizeof * 3, vertices.ptr, GL_STATIC_DRAW); 

        glGenBuffers(1, &nbo);
        glBindBuffer(GL_ARRAY_BUFFER, nbo);
        glBufferData(GL_ARRAY_BUFFER, normals.length * float.sizeof * 3, normals.ptr, GL_STATIC_DRAW);

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
    
        glEnableVertexAttribArray(VertexAttrib.Normals);
        glBindBuffer(GL_ARRAY_BUFFER, nbo);
        glVertexAttribPointer(VertexAttrib.Normals, 3, GL_FLOAT, GL_FALSE, 0, null);
    
        glEnableVertexAttribArray(VertexAttrib.Texcoords);
        glBindBuffer(GL_ARRAY_BUFFER, tbo);
        glVertexAttribPointer(VertexAttrib.Texcoords, 2, GL_FLOAT, GL_FALSE, 0, null);

        glBindVertexArray(0);
        
        canRender = true;
    }
    
    void update(double dt)
    {
    }
    
    void render(RenderingContext* rc)
    {
        if (canRender)
        {
            glBindVertexArray(vao);
            glDrawElements(GL_TRIANGLES, cast(uint)indices.length * 3, GL_UNSIGNED_INT, cast(void*)0);
            glBindVertexArray(0);
        }
    }
}

