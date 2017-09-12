module dagon.graphics.shapes;

import dlib.core.memory;
import dlib.math.vector;
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

// TODO: other shapes from original Dagon
