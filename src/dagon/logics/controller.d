module dagon.logics.controller;

import dlib.math.vector;
import dlib.math.matrix;
import dlib.math.transformation;
import dlib.math.quaternion;
import dlib.math.utils;

import dagon.core.ownership;
import dagon.logics.entity;

abstract class EntityController: Owner
{
    Entity entity;

    this(Entity e)
    {
        super(e);
        entity = e;
    }

    void update(double dt);
}

class DefaultEntityController: EntityController
{
    bool swapZY = false;

    this(Entity e)
    {
        super(e);
    }

    override void update(double dt)
    {
        entity.transformation = 
            translationMatrix(entity.position) *
            entity.rotation.toMatrix4x4 *
            scaleMatrix(entity.scaling);
            
        if (swapZY)
            entity.transformation = entity.transformation * rotationMatrix(Axis.x, degtorad(90.0f));
            
        entity.invTransformation = entity.transformation.inverse;
    }
}

