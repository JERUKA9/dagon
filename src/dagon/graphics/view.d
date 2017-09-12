module dagon.graphics.view;

import dlib.math.vector;
import dlib.math.matrix;
import dagon.graphics.rc;

interface View
{
    void update(double dt);
    Matrix4x4f viewMatrix();
    Matrix4x4f invViewMatrix();
    Vector3f cameraPosition();

    final void prepareRC(RenderingContext* rc)
    {
        rc.viewMatrix = viewMatrix();
        rc.invViewMatrix = invViewMatrix();
        rc.modelViewMatrix = rc.viewMatrix;
        rc.normalMatrix = rc.invViewMatrix.transposed;
        rc.cameraPosition = cameraPosition();
    }
}
