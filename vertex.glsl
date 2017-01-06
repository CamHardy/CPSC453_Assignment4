// ==========================================================================
// Vertex program for barebones GLFW boilerplate
//
// Author:  Sonny Chan, University of Calgary
// Edits n stuff made by me, Cameron Hardy
// Date:    2016
// ==========================================================================
#version 410

// location indices for these attributes correspond to those specified in the
// InitializeGeometry() function of the main program
layout(location = 0) in vec2 VertexPosition;
layout(location = 1) in vec2 VertexUV;

// output to be interpolated between vertices and passed to the fragment stage
out vec2 uv;
out vec2 position;


void main()
{
    gl_Position = vec4(VertexPosition, 0.0, 1.0);
	   uv = VertexUV;
    position = VertexPosition;
}
