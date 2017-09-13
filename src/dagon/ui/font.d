module dagon.ui.font;

import dlib.image.color;
import dagon.core.ownership;
import dagon.graphics.rc;

abstract class Font: Owner
{
    float height;
    float width(string str);
    void render(RenderingContext* rc, Color4f color, string str);
    
    this(Owner o)
    {
        super(o);
    }
}

