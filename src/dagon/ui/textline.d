module dagon.ui.textline;

import derelict.opengl.gl;
import derelict.freetype.ft;

import dlib.core.memory;
import dlib.math.vector;
import dlib.image.color;

import dagon.core.interfaces;
import dagon.core.ownership;
import dagon.ui.font;

enum Alignment
{
    Left,
    Right,
    Center
}

class TextLine: Owner, Drawable
{
    Font font;
    float scaling;
    Alignment alignment;
    Color4f color;
    string text;
    float width;
    float height;

    this(Font font, string text, Owner o)
    {
        super(o);
        this.font = font;
        this.text = text;
        this.scaling = 1.0f;
        this.width = font.width(text);
        this.height = font.height;
        this.alignment = Alignment.Left;
        this.color = Color4f(0, 0, 0);
    }

    override void update(double dt)
    {
    }

    override void render(RenderingContext* rc)
    {
        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        font.render(rc, color, text);
        glDisable(GL_BLEND);
    }

    void setFont(Font font)
    {
        this.font = font;
        this.width = font.width(text);
        this.height = font.height;
    }

    void setText(string text)
    {
        this.text = text;
        this.width = font.width(text);
    }
}

