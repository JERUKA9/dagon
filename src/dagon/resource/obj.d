module dagon.resource.obj;

import std.stdio;
import std.string;
import std.format;

import dlib.core.memory;
import dlib.core.stream;
import dlib.math.vector;
import dlib.geometry.triangle;
import dlib.filesystem.filesystem;
import dlib.filesystem.stdfs;
import dlib.container.array;
import derelict.opengl.gl;
import dagon.core.ownership;
import dagon.core.interfaces;
import dagon.resource.asset;
import dagon.graphics.mesh;

/*
class ObjMesh: Mesh
{
    Vector3f[] tmpVertices;
    Vector3f[] normals;
    Vector2f[] texcoords1;
    Vector2f[] texcoords2;
    
    ObjFace[] faces;
    uint displayList;

    this(Owner o)
    {
        super(o);
    }

    ~this()
    {
        if (glIsList(displayList))
            glDeleteLists(displayList, 1);

        if (vertices.length)
            Delete(vertices);
        if (normals.length)
            Delete(normals);
        if (texcoords1.length)
            Delete(texcoords1);
        if (texcoords2.length)
            Delete(texcoords2);
        if (faces.length)
            Delete(faces);
    }

    void createDisplayList()
    {
        displayList = glGenLists(1);
        glNewList(displayList, GL_COMPILE);
        
        glBegin(GL_TRIANGLES);
        foreach(f; faces)
        {
            if (normals.length) glNormal3fv(normals[f.n[0]].arrayof.ptr);
            if (texcoords1.length) glTexCoord2fv(texcoords1[f.t1[0]].arrayof.ptr);
            if (vertices.length) glVertex3fv(vertices[f.v[0]].arrayof.ptr);
            
            if (normals.length) glNormal3fv(normals[f.n[1]].arrayof.ptr);
            if (texcoords1.length) glTexCoord2fv(texcoords1[f.t1[1]].arrayof.ptr);
            if (vertices.length) glVertex3fv(vertices[f.v[1]].arrayof.ptr);
            
            if (normals.length) glNormal3fv(normals[f.n[2]].arrayof.ptr);
            if (texcoords1.length) glTexCoord2fv(texcoords1[f.t1[2]].arrayof.ptr);
            if (vertices.length) glVertex3fv(vertices[f.v[2]].arrayof.ptr);
        }
        glEnd();
        
        glEndList();
    }

    int opApply(scope int delegate(Triangle t) dg)
    {
        int result = 0;

        foreach(i, ref f; faces)
        {
            Triangle tri;

            tri.v[0] = vertices[f.v[0]];
            tri.v[1] = vertices[f.v[1]];
            tri.v[2] = vertices[f.v[2]];
            tri.n[0] = normals[f.n[0]];
            tri.n[1] = normals[f.n[1]];
            tri.n[2] = normals[f.n[2]];
            tri.t1[0] = texcoords1[f.t1[0]];
            tri.t1[1] = texcoords1[f.t1[1]];
            tri.t1[2] = texcoords1[f.t1[2]];
            tri.normal = (tri.n[0] + tri.n[1] + tri.n[2]) / 3.0f;

            result = dg(tri);
            if (result)
                break;
        }

        return result;
    }

    void update(double dt)
    {
    }

    void render(RenderingContext* rc)
    {
        //glEnable(GL_CULL_FACE);
        if (glIsList(displayList))
            glCallList(displayList);
        //glDisable(GL_CULL_FACE);
    }
}
*/

struct ObjFace
{
    uint[3] v;
    uint[3] t;
    uint[3] n;
}

class OBJAsset: Asset
{
    Mesh mesh;

    this(Owner o)
    {
        super(o);
        mesh = New!Mesh(this);
    }

    ~this()
    {
        release();
    }

    override bool loadThreadSafePart(string filename, InputStream istrm, ReadOnlyFileSystem fs, AssetManager mngr)
    {
        uint numVerts = 0;
        uint numNormals = 0;
        uint numTexcoords = 0;
        uint numFaces = 0;

        string fileStr = readText(istrm);
        foreach(line; lineSplitter(fileStr))
        {
            if (line.startsWith("v "))
                numVerts++;
            else if (line.startsWith("vn "))
                numNormals++;
            else if (line.startsWith("vt "))
                numTexcoords++;
            else if (line.startsWith("f "))
                numFaces++;
        }
        
        Vector3f[] tmpVertices;
        Vector3f[] tmpNormals;
        Vector2f[] tmpTexcoords;
        ObjFace[] tmpFaces;

        if (numVerts)
            tmpVertices = New!(Vector3f[])(numVerts);
        if (numNormals)
            tmpNormals = New!(Vector3f[])(numNormals);
        if (numTexcoords)
            tmpTexcoords = New!(Vector2f[])(numTexcoords);
        if (numFaces)
            tmpFaces = New!(ObjFace[])(numFaces);

        float x, y, z;
        int v1, v2, v3;
        int t1, t2, t3;
        int n1, n2, n3;
        uint vi = 0;
        uint ni = 0;
        uint ti = 0;
        uint fi = 0;

        foreach(line; lineSplitter(fileStr))
        {
            if (line.startsWith("v "))
            {
                if (formattedRead(line, "v %s %s %s", &x, &y, &z))
                {
                    tmpVertices[vi] = Vector3f(x, y, z);
                    vi++;
                }
            }
            else if (line.startsWith("vn"))
            {
                if (formattedRead(line, "vn %s %s %s", &x, &y, &z))
                {
                    tmpNormals[ni] = Vector3f(x, y, z);
                    ni++;
                }
            }
            else if (line.startsWith("vt"))
            {
                if (formattedRead(line, "vt %s %s", &x, &y))
                {
                    tmpTexcoords[ti] = Vector2f(x, -y);
                    ti++;
                }
            }
            else if (line.startsWith("vp"))
            {
            }
            else if (line.startsWith("f"))
            {
                if (formattedRead(line, "f %s/%s/%s %s/%s/%s %s/%s/%s", &v1, &t1, &n1, &v2, &t2, &n2, &v3, &t3, &n3))
                {
                    tmpFaces[fi].v[0] = v1-1;
                    tmpFaces[fi].v[1] = v2-1;
                    tmpFaces[fi].v[2] = v3-1;
                    
                    tmpFaces[fi].t[0] = t1-1;
                    tmpFaces[fi].t[1] = t2-1;
                    tmpFaces[fi].t[2] = t3-1;
                    
                    tmpFaces[fi].n[0] = n1-1;
                    tmpFaces[fi].n[1] = n2-1;
                    tmpFaces[fi].n[2] = n3-1;
                    
                    fi++;
                }
                else if (formattedRead(line, "f %s//%s %s//%s %s//%s", &v1, &n1, &v2, &n2, &v3, &n3))
                {
                    tmpFaces[fi].v[0] = v1-1;
                    tmpFaces[fi].v[1] = v2-1;
                    tmpFaces[fi].v[2] = v3-1;
                    
                    tmpFaces[fi].n[0] = n1-1;
                    tmpFaces[fi].n[1] = n2-1;
                    tmpFaces[fi].n[2] = n3-1;
                    
                    fi++;
                }
                else if (formattedRead(line, "f %s %s %s", &v1, &v2, &v3))
                {
                    tmpFaces[fi].v[0] = v1-1;
                    tmpFaces[fi].v[1] = v2-1;
                    tmpFaces[fi].v[2] = v3-1;
                    
                    fi++;
                }
            }
        }

        Delete(fileStr);
        
        assert(tmpFaces.length);
        assert(tmpVertices.length);
        assert(tmpNormals.length);
        assert(tmpTexcoords.length);
        
        mesh.indices = New!(uint[3][])(tmpFaces.length);
        uint numUniqueVerts = cast(uint)mesh.indices.length * 3;
        mesh.vertices = New!(Vector3f[])(numUniqueVerts);
        mesh.normals = New!(Vector3f[])(numUniqueVerts);
        mesh.texcoords = New!(Vector2f[])(numUniqueVerts);
                
        uint index = 0;
        
        foreach(i, ref ObjFace f; tmpFaces)
        {
            mesh.vertices[index] = tmpVertices[f.v[0]];
            mesh.vertices[index+1] = tmpVertices[f.v[1]];
            mesh.vertices[index+2] = tmpVertices[f.v[2]];

            mesh.normals[index] = tmpNormals[f.n[0]];
            mesh.normals[index+1] = tmpNormals[f.n[1]];
            mesh.normals[index+2] = tmpNormals[f.n[2]];
            
            mesh.texcoords[index] = tmpTexcoords[f.t[0]];
            mesh.texcoords[index+1] = tmpTexcoords[f.t[1]];
            mesh.texcoords[index+2] = tmpTexcoords[f.t[2]];
            
            mesh.indices[i][0] = index;
            mesh.indices[i][1] = index + 1;
            mesh.indices[i][2] = index + 2;
            
            index += 3;
        }
        
        if (tmpVertices.length)
            Delete(tmpVertices);
        if (tmpNormals.length)
            Delete(tmpNormals);
        if (tmpTexcoords.length)
            Delete(tmpTexcoords);
        if (tmpFaces.length)
            Delete(tmpFaces);
        
        mesh.dataReady = true;

        return true;
    }

    override bool loadThreadUnsafePart()
    {
        mesh.prepareVAO();
        return true;
    }

    override void release()
    {
        clearOwnedObjects();
    }
}

