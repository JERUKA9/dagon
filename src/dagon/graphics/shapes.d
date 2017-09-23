module dagon.graphics.shapes;

import std.math;
import dlib.core.memory;
import dlib.math.vector;
import dlib.container.array;
import derelict.opengl.gl;
import dagon.core.interfaces;
import dagon.core.ownership;
import dagon.graphics.mesh;

class ShapePlane: Mesh
{
    this(float sx, float sz, uint numTiles, Owner owner)
    {
        super(owner);
        
        float px = -sx * 0.5f;
        float py = -sz * 0.5f;
        
        float tileWidth = sx / numTiles;
        float tileHeight = sz / numTiles;
        
        Vector3f start = Vector3f(px, 0.0f, py);
        
        uint gridSize = numTiles + 1;
        
        vertices = New!(Vector3f[])(gridSize * gridSize);
        normals = New!(Vector3f[])(gridSize * gridSize);
        texcoords = New!(Vector2f[])(gridSize * gridSize);

        for (uint i = 0, y = 0; y < gridSize; y++)
        for (uint x = 0; x < gridSize; x++, i++)
        {
            vertices[i] = start + Vector3f(x * tileWidth, 0, y * tileHeight);
            normals[i] = Vector3f(0, 1, 0);
            texcoords[i] = Vector2f(x, y);
        }     
        
        indices = New!(uint[3][])(gridSize * gridSize * 2);
        
        uint index = 0;
        for (uint y = 0; y < gridSize - 1; y++)
        for (uint x = 0; x < gridSize - 1; x++)
        {
            uint offset = y * gridSize + x;
            indices[index][2] = (offset + 0);
            indices[index][1] = (offset + 1);
            indices[index][0] = (offset + gridSize);
            
            indices[index+1][2] = (offset + 1);
            indices[index+1][1] = (offset + gridSize + 1);
            indices[index+1][0] = (offset + gridSize);
            
            index += 2;
        }

        dataReady = true;
        prepareVAO();
    }
}

class ShapeQuad: Owner, Drawable
{
    Vector2f[4] vertices;
    Vector2f[4] texcoords;
    uint[3][2] indices;
    
    GLuint vao = 0;
    GLuint vbo = 0;
    GLuint tbo = 0;
    GLuint eao = 0;
    
    this(Owner o)
    {
        super(o);

        vertices[0] = Vector2f(0, 1);
        vertices[1] = Vector2f(0, 0);
        vertices[2] = Vector2f(1, 0);
        vertices[3] = Vector2f(1, 1);
        
        texcoords[0] = Vector2f(0, 1);
        texcoords[1] = Vector2f(0, 0);
        texcoords[2] = Vector2f(1, 0);
        texcoords[3] = Vector2f(1, 1);
        
        indices[0][0] = 0;
        indices[0][1] = 1;
        indices[0][2] = 2;
        
        indices[1][0] = 0;
        indices[1][1] = 2;
        indices[1][2] = 3;
        
        glGenBuffers(1, &vbo);
        glBindBuffer(GL_ARRAY_BUFFER, vbo);
        glBufferData(GL_ARRAY_BUFFER, vertices.length * float.sizeof * 2, vertices.ptr, GL_STATIC_DRAW); 

        glGenBuffers(1, &tbo);
        glBindBuffer(GL_ARRAY_BUFFER, tbo);
        glBufferData(GL_ARRAY_BUFFER, texcoords.length * float.sizeof * 2, texcoords.ptr, GL_STATIC_DRAW);

        glGenBuffers(1, &eao);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, eao);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, indices.length * uint.sizeof * 3, indices.ptr, GL_STATIC_DRAW);

        glGenVertexArrays(1, &vao);
        glBindVertexArray(vao);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, eao);
    
        glEnableVertexAttribArray(0);
        glBindBuffer(GL_ARRAY_BUFFER, vbo);
        glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, null);
    
        glEnableVertexAttribArray(1);
        glBindBuffer(GL_ARRAY_BUFFER, tbo);
        glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 0, null);

        glBindVertexArray(0);
    }
    
    ~this()
    {            
        glDeleteVertexArrays(1, &vao);
        glDeleteBuffers(1, &vbo);
        glDeleteBuffers(1, &tbo);
        glDeleteBuffers(1, &eao);
    }
    
    void update(double dt)
    {
    }
    
    void render(RenderingContext* rc)
    {        
        glDepthMask(0);
        glBindVertexArray(vao);
        glDrawElements(GL_TRIANGLES, cast(uint)indices.length * 3, GL_UNSIGNED_INT, cast(void*)0);
        glBindVertexArray(0);
        glDepthMask(1);
    }
}

// TODO: other shapes from original Dagon
