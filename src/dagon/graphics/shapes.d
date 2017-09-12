module dagon.graphics.shapes;

import dlib.core.memory;
import dlib.math.vector;
import derelict.opengl.gl;
import dagon.core.interfaces;
import dagon.core.ownership;
import dagon.graphics.mesh;

class ShapeTriangle: Mesh
{
    this(Owner owner)
    {
        super(owner);
        
        vertices = New!(Vector3f[])(3);
        normals = New!(Vector3f[])(3);
        texcoords = New!(Vector2f[])(3);        
        indices = New!(uint[3][])(1);
        
        vertices[0] = Vector3f( 1, 0, 0);
        vertices[1] = Vector3f(-1, 0, 0);
        vertices[2] = Vector3f( 0, 0, 1);
        
        normals[0] = Vector3f(0, 1, 0);
        normals[1] = Vector3f(0, 1, 0);
        normals[2] = Vector3f(0, 1, 0);
        
        texcoords[0] = Vector2f(1, 0);
        texcoords[1] = Vector2f(0, 0);
        texcoords[2] = Vector2f(0.5, 1);
        
        indices[0] = [0, 1, 2];
        
        dataReady = true;
        prepareVAO();
    }
    
    ~this()
    {
        Delete(vertices);
        Delete(normals);
        Delete(texcoords);
        Delete(indices);
    }
}

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
    
    ~this()
    {
        if (dataReady)
        {
            Delete(vertices);
            Delete(normals);
            Delete(texcoords);
            Delete(indices);
        }
    }
}

class ShapeBox: Mesh
{
    this(float sx, float sy, float sz, Owner owner)
    {
        this(Vector3f(sx, sy, sz), owner);
    }

    this(Vector3f hsize, Owner owner)
    {
        super(owner);
        
        // TODO:
        
        //dataReady = true;
        //prepareVAO();
    }
    
    ~this()
    {
        if (dataReady)
        {
            Delete(vertices);
            Delete(normals);
            Delete(texcoords);
            Delete(indices);
        }
    }
}

/++
class ShapeBox: Owner, Drawable
{
    //uint displayList;
    GLuint vbo;

    this(float sx, float sy, float sz, Owner owner)
    {
        this(Vector3f(sx, sy, sz), owner);
    }

    this(Vector3f hsize, Owner owner)
    {
        super(owner);
        
        /*
        displayList = glGenLists(1);
        glNewList(displayList, GL_COMPILE);

        Vector3f pmax = +hsize;
        Vector3f pmin = -hsize;

        glBegin(GL_QUADS);

        glTexCoord2f(0, 1); glNormal3f(0,0,1); glVertex3f(pmin.x,pmin.y,pmax.z);
        glTexCoord2f(1, 1); glNormal3f(0,0,1); glVertex3f(pmax.x,pmin.y,pmax.z);
        glTexCoord2f(1, 0); glNormal3f(0,0,1); glVertex3f(pmax.x,pmax.y,pmax.z);
        glTexCoord2f(0, 0); glNormal3f(0,0,1); glVertex3f(pmin.x,pmax.y,pmax.z);

        glTexCoord2f(0, 1); glNormal3f(1,0,0); glVertex3f(pmax.x,pmin.y,pmax.z);
        glTexCoord2f(1, 1); glNormal3f(1,0,0); glVertex3f(pmax.x,pmin.y,pmin.z);
        glTexCoord2f(1, 0); glNormal3f(1,0,0); glVertex3f(pmax.x,pmax.y,pmin.z);
        glTexCoord2f(0, 0); glNormal3f(1,0,0); glVertex3f(pmax.x,pmax.y,pmax.z);

        glTexCoord2f(0, 1); glNormal3f(0,1,0); glVertex3f(pmin.x,pmax.y,pmax.z);
        glTexCoord2f(1, 1); glNormal3f(0,1,0); glVertex3f(pmax.x,pmax.y,pmax.z);
        glTexCoord2f(1, 0); glNormal3f(0,1,0); glVertex3f(pmax.x,pmax.y,pmin.z);
        glTexCoord2f(0, 0); glNormal3f(0,1,0); glVertex3f(pmin.x,pmax.y,pmin.z);

        glTexCoord2f(0, 1); glNormal3f(0,0,-1); glVertex3f(pmin.x,pmin.y,pmin.z);
        glTexCoord2f(1, 1); glNormal3f(0,0,-1); glVertex3f(pmin.x,pmax.y,pmin.z);
        glTexCoord2f(1, 0); glNormal3f(0,0,-1); glVertex3f(pmax.x,pmax.y,pmin.z);
        glTexCoord2f(0, 0); glNormal3f(0,0,-1); glVertex3f(pmax.x,pmin.y,pmin.z);

        glTexCoord2f(0, 1); glNormal3f(0,-1,0); glVertex3f(pmin.x,pmin.y,pmin.z);
        glTexCoord2f(1, 1); glNormal3f(0,-1,0); glVertex3f(pmax.x,pmin.y,pmin.z);
        glTexCoord2f(1, 0); glNormal3f(0,-1,0); glVertex3f(pmax.x,pmin.y,pmax.z);
        glTexCoord2f(0, 0); glNormal3f(0,-1,0); glVertex3f(pmin.x,pmin.y,pmax.z);

        glTexCoord2f(0, 1); glNormal3f(-1,0,0); glVertex3f(pmin.x,pmin.y,pmin.z);
        glTexCoord2f(1, 1); glNormal3f(-1,0,0); glVertex3f(pmin.x,pmin.y,pmax.z);
        glTexCoord2f(1, 0); glNormal3f(-1,0,0); glVertex3f(pmin.x,pmax.y,pmax.z);
        glTexCoord2f(0, 0); glNormal3f(-1,0,0); glVertex3f(pmin.x,pmax.y,pmin.z);

        glEnd();

        glEndList();
        */
    }

    void update(double dt)
    {
    }

    void render(RenderingContext* rc)
    {
        glCallList(displayList);
    }

    ~this()
    {
        glDeleteLists(displayList, 1);
    }
}
++/

version(None):

class ShapeSphere: Owner, Drawable
{
    uint displayList;

    this(float r, Owner owner)
    {
        super(owner);

        GLUquadricObj* quadric = gluNewQuadric();
        gluQuadricNormals(quadric, GLU_SMOOTH);
        gluQuadricTexture(quadric, GL_TRUE);

        displayList = glGenLists(1);
        glNewList(displayList, GL_COMPILE);
        gluSphere(quadric, r, 24, 16);
        glEndList();

        gluDeleteQuadric(quadric);
    }

    void update(double dt)
    {
    }

    void render(RenderingContext* rc)
    {
        glCallList(displayList);
    }

    ~this()
    {
        glDeleteLists(displayList, 1);
    }
}

class ShapeCylinder: Owner, Drawable
{
    // TODO: slices, stacks
    uint displayList;

    this(float h, float r, Owner o)
    {
        super(o);
        GLUquadricObj* quadric = gluNewQuadric();
        gluQuadricNormals(quadric, GLU_SMOOTH);
        gluQuadricTexture(quadric, GL_TRUE);

        displayList = glGenLists(1);
        glNewList(displayList, GL_COMPILE);
        glTranslatef(0.0f, h * 0.5f, 0.0f);
        glRotatef(90.0f, 1.0f, 0.0f, 0.0f);
        gluCylinder(quadric, r, r, h, 16, 2);
        gluQuadricOrientation(quadric, GLU_INSIDE);
        gluDisk(quadric, 0, r, 16, 1);
        gluQuadricOrientation(quadric, GLU_OUTSIDE);
        glTranslatef(0.0f, 0.0f, h);
        gluDisk(quadric, 0, r, 16, 1);
        glEndList();

        gluDeleteQuadric(quadric);
    }

    void update(double dt)
    {
    }

    void render(RenderingContext* rc)
    {
        glCallList(displayList);
    }

    ~this()
    {
        glDeleteLists(displayList, 1);
    }
}

/*
class ShapeCone: Drawable
{
    // TODO: slices, stacks
    uint displayList;

    this(float h, float r)
    {
        GLUquadricObj* quadric = gluNewQuadric();
        gluQuadricNormals(quadric, GLU_SMOOTH);
        gluQuadricTexture(quadric, GL_TRUE);

        displayList = glGenLists(1);
        glNewList(displayList, GL_COMPILE);
        glTranslatef(0.0f, 0.0f, -h * 0.5f);
        gluCylinder(quadric, r, 0.0f, h, 16, 2);
        gluQuadricOrientation(quadric, GLU_INSIDE);
        gluDisk(quadric, 0, r, 16, 1);
        glEndList();

        gluDeleteQuadric(quadric);
    }

    override void draw(double dt)
    {
        glCallList(displayList);
    }

    ~this()
    {
        glDeleteLists(displayList, 1);
    }
}

class ShapeEllipsoid: Drawable
{
    uint displayList;
    Vector3f radii;

    this(float rx, float ry, float rz)
    {
        this(Vector3f(rx, ry, rz));
    }

    this(Vector3f r)
    {
        radii = r;

        GLUquadricObj*  quadric = gluNewQuadric();
        gluQuadricNormals(quadric, GLU_SMOOTH);
        gluQuadricTexture(quadric, GL_TRUE);

        displayList = glGenLists(1);
        glNewList(displayList, GL_COMPILE);
        gluSphere(quadric, 1.0f, 24, 16);
        glEndList();

        gluDeleteQuadric(quadric);
    }

    override void draw(double dt)
    {
        glPushMatrix();
        glScalef(radii.x, radii.y, radii.z);
        glCallList(displayList);
        glPopMatrix();
    }

    ~this()
    {
        glDeleteLists(displayList, 1);
    }
}
*/

