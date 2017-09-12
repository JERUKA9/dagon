module dagon;

public
{
    import derelict.sdl2.sdl;
    import derelict.opengl.gl;

    import dlib.core;
    import dlib.math;
    import dlib.geometry;
    import dlib.image;
    import dlib.container;

    import dagon.core.ownership;
    import dagon.core.interfaces;
    import dagon.core.application;
    import dagon.core.event;
    import dagon.core.keycodes;
    import dagon.core.vfs;

    import dagon.resource.scene;
    import dagon.resource.asset;
    import dagon.resource.textasset;
    import dagon.resource.textureasset;
    import dagon.resource.obj;

    import dagon.logics.entity;
    import dagon.logics.controller;
    import dagon.logics.behaviour;
    import dagon.logics.stdbehaviour;

    import dagon.graphics.rc;
    import dagon.graphics.tbcamera;
    import dagon.graphics.freeview;
    import dagon.graphics.shapes;
    import dagon.graphics.texture;
    import dagon.graphics.material;
    import dagon.graphics.environment;
    import dagon.graphics.mesh;
    import dagon.graphics.view;
    
    import dagon.graphics.materials.generic;

    import dagon.templates.basescene;
}

