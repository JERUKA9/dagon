module dagon.resource.textureasset;

import std.stdio;
import std.path;

import dlib.core.memory;
import dlib.core.stream;
import dlib.core.compound;
import dlib.image.image;
import dlib.image.io.bmp;
import dlib.image.io.png;
import dlib.image.io.tga;
import dlib.image.io.jpeg;
import dlib.image.unmanaged;
import dlib.filesystem.filesystem;

import dagon.core.ownership;
import dagon.resource.asset;
import dagon.graphics.texture;

class TextureAsset: Asset
{
    UnmanagedImageFactory imageFactory;
    //SuperImage image;
    Texture texture;

    this(UnmanagedImageFactory imgfac, Owner o)
    {
        super(o);
        imageFactory = imgfac;
        texture = New!Texture(this);
    }

    ~this()
    {
        release();
    }

    override bool loadThreadSafePart(string filename, InputStream istrm, ReadOnlyFileSystem fs, AssetManager mngr)
    {
        Compound!(SuperImage, string) res;
        switch(filename.extension)
        {
            case ".bmp", ".BMP":
                res = loadBMP(istrm, imageFactory);
                break;
            case ".jpg", ".JPG", ".jpeg", ".JPEG":
                res = loadJPEG(istrm, imageFactory);
                break;
            case ".png", ".PNG":
                res = loadPNG(istrm, imageFactory);
                break;
            case ".tga", ".TGA":
                res = loadTGA(istrm, imageFactory);
                break;
            default:
                return false;
        }

        //auto res = loadPNG(istrm, imageFactory);
        texture.image = res[0];
        if (texture.image !is null)
        {
            return true;
        }
        else
        {
            writeln(res[1]);
            return false;
        }
    }

    override bool loadThreadUnsafePart()
    {
        if (texture.image !is null)
        {
            texture.createFromImage(texture.image);
            if (texture.valid)
            {
                return true;
            }
            else
                return false;
        }
        else
        {
            return false;
        }
    }

    override void release()
    {
        if (texture)
            texture.release();
    }
}

