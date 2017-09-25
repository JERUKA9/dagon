module dagon.graphics.texture;

import std.stdio;
import std.math;

import derelict.opengl.gl;

import dlib.core.memory;
import dlib.image.image;
import dlib.math.vector;

import dagon.core.ownership;

class Texture: Owner
{
    SuperImage image;
    
    GLuint tex;
    GLenum format;
    GLint intFormat;
    GLenum type;
    
    int width;
    int height;
    int numMipmapLevels;
    
    Vector2f translation;
    Vector2f scale;
    float rotation;

    this(Owner o)
    {
        super(o);
        translation = Vector2f(0.0f, 0.0f);
        scale = Vector2f(1.0f, 1.0f);
        rotation = 0.0f;
    }

/*
    this(uint w, uint h, Owner o)
    {
        super(o);
        translation = Vector2f(0.0f, 0.0f);
        scale = Vector2f(1.0f, 1.0f);
        rotation = 0.0f;

        width = w;
        height = h;

        glGenTextures(1, &tex);
        glBindTexture(GL_TEXTURE_2D, tex);
        glTexImage2D(GL_TEXTURE_2D, 0, 4, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, null);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    }

*/
    this(SuperImage img, Owner o, bool genMipmaps = false)
    {
        super(o);
        translation = Vector2f(0.0f, 0.0f);
        scale = Vector2f(1.0f, 1.0f);
        rotation = 0.0f;
        createFromImage(img, genMipmaps);
    }

    void createFromImage(SuperImage img, bool genMipmaps = false)
    {
        image = img;
        width = img.width;
        height = img.height;

        type = GL_UNSIGNED_BYTE;

        switch (img.pixelFormat)
        {
            case PixelFormat.L8:     intFormat = GL_R8;     format = GL_RED; break;
            case PixelFormat.LA8:    intFormat = GL_RG8;    format = GL_RG; break;
            case PixelFormat.RGB8:   intFormat = GL_RGB8;   format = GL_RGB; break;
            case PixelFormat.RGBA8:  intFormat = GL_RGBA8;  format = GL_RGBA; break;
            default:
                writefln("Unsupported pixel format %s", img.pixelFormat);
                return;
        }

        glGenTextures(1, &tex);
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, tex);

        glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
        
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);

        numMipmapLevels = cast(int)log2(fmax(width, height)) + 1;
       
        glTexImage2D(GL_TEXTURE_2D, 0, intFormat, width, height, 0, format, type, cast(void*)img.data.ptr);

        glGenerateMipmap(GL_TEXTURE_2D);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_BASE_LEVEL, 0);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, numMipmapLevels - 1);

        glBindTexture(GL_TEXTURE_2D, 0);
    }

    void bind()
    {
        if (glIsTexture(tex))
            glBindTexture(GL_TEXTURE_2D, tex);
    }

    void unbind()
    {
        glBindTexture(GL_TEXTURE_2D, 0);
    }
    
    bool valid()
    {
        return cast(bool)glIsTexture(tex);
    }

    void release()
    {
        if (glIsTexture(tex))
            glDeleteTextures(1, &tex);
        if (image)
        {
            Delete(image);
            image = null;
        }
    }

    ~this()
    {
        release();
    }
}

