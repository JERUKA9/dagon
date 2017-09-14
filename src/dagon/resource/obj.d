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

import std.regex;

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
        
        if (!numVerts)
            writeln("Warning: OBJ file \"", filename, "\" has no vertices");
        if (!numNormals)
            writeln("Warning: OBJ file \"", filename, "\" has no normals");
        if (!numTexcoords)
            writeln("Warning: OBJ file \"", filename, "\" has no texcoords");

        if (numVerts)
            tmpVertices = New!(Vector3f[])(numVerts);
        if (numNormals)
            tmpNormals = New!(Vector3f[])(numNormals);
        if (numTexcoords)
            tmpTexcoords = New!(Vector2f[])(numTexcoords);
        if (numFaces)
            tmpFaces = New!(ObjFace[])(numFaces);

        float x, y, z;
        int v1, v2, v3, v4;
        int t1, t2, t3, t4;
        int n1, n2, n3, n4;
        uint vi = 0;
        uint ni = 0;
        uint ti = 0;
        uint fi = 0;
        
        bool warnAboutQuads = false;

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
                char[256] tmpStr;
                tmpStr[0..line.length] = line[];
                tmpStr[line.length] = 0;
            
                if (sscanf(tmpStr.ptr, "f %u/%u/%u %u/%u/%u %u/%u/%u %u/%u/%u", &v1, &t1, &n1, &v2, &t2, &n2, &v3, &t3, &n3, &v4, &t4, &n4) == 12)
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
                    
                    warnAboutQuads = true;
                }
                if (sscanf(tmpStr.ptr, "f %u/%u/%u %u/%u/%u %u/%u/%u", &v1, &t1, &n1, &v2, &t2, &n2, &v3, &t3, &n3) == 9)
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
                else if (sscanf(tmpStr.ptr, "f %u//%u %u//%u %u//%u %u//%u", &v1, &n1, &v2, &n2, &v3, &n3, &v4, &n4) == 8)
                {
                    tmpFaces[fi].v[0] = v1-1;
                    tmpFaces[fi].v[1] = v2-1;
                    tmpFaces[fi].v[2] = v3-1;
                    
                    tmpFaces[fi].n[0] = n1-1;
                    tmpFaces[fi].n[1] = n2-1;
                    tmpFaces[fi].n[2] = n3-1;
                    
                    fi++;
                    
                    warnAboutQuads = true;
                } 
                else if (sscanf(tmpStr.ptr, "f %u//%u %u//%u %u//%u", &v1, &n1, &v2, &n2, &v3, &n3) == 6)
                {
                    tmpFaces[fi].v[0] = v1-1;
                    tmpFaces[fi].v[1] = v2-1;
                    tmpFaces[fi].v[2] = v3-1;
                    
                    tmpFaces[fi].n[0] = n1-1;
                    tmpFaces[fi].n[1] = n2-1;
                    tmpFaces[fi].n[2] = n3-1;
                    
                    fi++;
                }
                else if (sscanf(tmpStr.ptr, "f %u %u %u %u", &v1, &v2, &v3, &v4) == 4)
                {
                    tmpFaces[fi].v[0] = v1-1;
                    tmpFaces[fi].v[1] = v2-1;
                    tmpFaces[fi].v[2] = v3-1;
                    
                    fi++;
                    
                    warnAboutQuads = true;
                }
                else if (sscanf(tmpStr.ptr, "f %u %u %u", &v1, &v2, &v3) == 3)
                {
                    tmpFaces[fi].v[0] = v1-1;
                    tmpFaces[fi].v[1] = v2-1;
                    tmpFaces[fi].v[2] = v3-1;
                    
                    fi++;
                }
                else
                    assert(0);
            }
        }

        Delete(fileStr);
        
        if (warnAboutQuads)
            writeln("Warning: OBJ file \"", filename, "\" includes quads, but Dagon supports only triangles");
        
        mesh.indices = New!(uint[3][])(tmpFaces.length);
        uint numUniqueVerts = cast(uint)mesh.indices.length * 3;
        mesh.vertices = New!(Vector3f[])(numUniqueVerts);
        mesh.normals = New!(Vector3f[])(numUniqueVerts);
        mesh.texcoords = New!(Vector2f[])(numUniqueVerts);
                
        uint index = 0;
        
        foreach(i, ref ObjFace f; tmpFaces)
        {
            if (numVerts)
            {
                mesh.vertices[index] = tmpVertices[f.v[0]];
                mesh.vertices[index+1] = tmpVertices[f.v[1]];
                mesh.vertices[index+2] = tmpVertices[f.v[2]];
            }
            else
            {
                mesh.vertices[index] = Vector3f(0, 0, 0);
                mesh.vertices[index+1] = Vector3f(0, 0, 0);
                mesh.vertices[index+2] = Vector3f(0, 0, 0);
            }

            if (numNormals)
            {
                mesh.normals[index] = tmpNormals[f.n[0]];
                mesh.normals[index+1] = tmpNormals[f.n[1]];
                mesh.normals[index+2] = tmpNormals[f.n[2]];
            }
            else
            {
                mesh.normals[index] = Vector3f(0, 0, 0);
                mesh.normals[index+1] = Vector3f(0, 0, 0);
                mesh.normals[index+2] = Vector3f(0, 0, 0);
            }
            
            if (numTexcoords)
            {
                mesh.texcoords[index] = tmpTexcoords[f.t[0]];
                mesh.texcoords[index+1] = tmpTexcoords[f.t[1]];
                mesh.texcoords[index+2] = tmpTexcoords[f.t[2]];
            }
            else
            {
                mesh.texcoords[index] = Vector2f(0, 0);
                mesh.texcoords[index+1] = Vector2f(0, 0);
                mesh.texcoords[index+2] = Vector2f(0, 0);
            }
            
            mesh.indices[i][0] = index;
            mesh.indices[i][1] = index + 1;
            mesh.indices[i][2] = index + 2;
            
            index += 3;
        }
        
        // TODO: generate normals if they are not present
        
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

