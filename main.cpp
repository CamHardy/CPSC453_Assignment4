// ==========================================================================
// Barebones OpenGL Core Profile Boilerplate
//    using the GLFW windowing system (http://www.glfw.org)
//
// Loosely based on
//  - Chris Wellons' example (https://github.com/skeeto/opengl-demo) and
//  - Camilla Berglund's example (http://www.glfw.org/docs/latest/quick.html)
//
// Author:  Sonny Chan, University of Calgary
// I edited this. They call me Hardy. Cam Hardy.
// Date:    2016
// ==========================================================================

#include <iostream>
#include <fstream>
#include <string>
#include <iterator>
#include <algorithm>
#include <vector>
#include "glm/glm.hpp"
#include "raytrace.h"
// specify that we want the OpenGL core profile before including GLFW headers
// specify that we want the OpenGL core profile before including GLFW headers
#ifdef _WIN32
#include <glad/glad.h>
#include <GLFW/glfw3.h>
#else
#define GLFW_INCLUDE_GLCOREARB
#define GL_GLEXT_PROTOTYPES
#include <GLFW/glfw3.h>
#endif

// #define PI 3.14159265359
#define WIDTH 640 // wanna change the window size? change these
#define HEIGHT 640 // this one too ok

vec3 cam1Origin;
vec3 cam2Origin;
vec3 pos;
float offset = 0.0;
float fov = 60;
float t = 0.0;
int mode = 0;
float delta = 0.2;
int scene = 0;
bool AA = false;
int cameraMode = 0;
float timey;
int stimey = 0;

using namespace std;
using namespace glm;

// Forward definitions
bool CheckGLErrors(string location);
void QueryGLVersion();
string LoadSource(const string &filename);
GLuint CompileShader(GLenum shaderType, const string &source);
GLuint LinkProgram(GLuint vertexShader, GLuint fragmentShader);

GLFWwindow* window = 0;


// --------------------------------------------------------------------------
// GLFW callback functions

// reports GLFW errors
void ErrorCallback(int error, const char* description)
{
    cout << "GLFW ERROR " << error << ":" << endl;
    cout << description << endl;
}

vector<vec2> points;
vector<vec2> uvs;

// Structs are simply acting as namespaces
// Access the values like so: VAO::LINES
struct VAO{
	enum {LINES=0, COUNT};		// Enumeration assigns each name a value going up
                                // LINES=0, COUNT=1
};

struct VBO{
	enum {POINTS=0, COLOR, COUNT};	// POINTS=0, COLOR=1, COUNT=2
};

struct SHADER{
	enum {LINE=0, COUNT};		// LINE=0, COUNT=1
};

GLuint vbo [VBO::COUNT];		// Array which stores OpenGL's vertex buffer object handles
GLuint vao [VAO::COUNT];		// Array which stores Vertex Array Object handles
GLuint shader [SHADER::COUNT];	// Array which stores shader program handles


// Gets handles from OpenGL
void generateIDs()
{
	glGenVertexArrays(VAO::COUNT, vao);		// Tells OpenGL to create VAO::COUNT many
                                            // Vertex Array Objects, and store their
                                            // handles in vao array
	glGenBuffers(VBO::COUNT, vbo);          // Tells OpenGL to create VBO::COUNT many
                                            // Vertex Buffer Objects and store their
                                            // handles in vbo array
}

// Clean up IDs when you're done using them
void deleteIDs()
{
	for(int i=0; i<SHADER::COUNT; i++)
	{
		glDeleteProgram(shader[i]);
	}

	glDeleteVertexArrays(VAO::COUNT, vao);
	glDeleteBuffers(VBO::COUNT, vbo);
}


// Describe the setup of the Vertex Array Object
bool initVAO()
{
	glBindVertexArray(vao[VAO::LINES]);		// Set the active Vertex Array

	glEnableVertexAttribArray(0);		// Tell opengl you're using layout attribute 0 (For shader input)
	glBindBuffer( GL_ARRAY_BUFFER, vbo[VBO::POINTS] );		// Set the active Vertex Buffer
	glVertexAttribPointer(
		0,				// Attribute
		2,				// Size # Components
		GL_FLOAT,	// Type
		GL_FALSE, 	// Normalized?
		sizeof(vec2),	// Stride
		(void*)0			// Offset
		);

	glEnableVertexAttribArray(1);		// Tell opengl you're using layout attribute 1
	glBindBuffer(GL_ARRAY_BUFFER, vbo[VBO::COLOR]);
	glVertexAttribPointer(
		1,
		2,
		GL_FLOAT,
		GL_FALSE,
		sizeof(vec2),
		(void*)0
		);

	return !CheckGLErrors("initVAO");		// Check for errors in initialize
}


// Loads buffers with data
bool loadBuffer(const vector<vec2>& points, const vector<vec2>& colors)
{
	glBindBuffer(GL_ARRAY_BUFFER, vbo[VBO::POINTS]);
	glBufferData(
		GL_ARRAY_BUFFER,				// Which buffer you're loading too
		sizeof(vec2)*points.size(),     // Size of data in array (in bytes)
		&points[0],						// Start of array (&points[0] will give you pointer to start of vector)
		GL_DYNAMIC_DRAW					// GL_DYNAMIC_DRAW if you're changing the data often
                                        // GL_STATIC_DRAW if you're changing seldomly
		);

	glBindBuffer(GL_ARRAY_BUFFER, vbo[VBO::COLOR]);
	glBufferData(
		GL_ARRAY_BUFFER,
		sizeof(vec2)*uvs.size(),
		&uvs[0],
		GL_STATIC_DRAW
		);

	return !CheckGLErrors("loadBuffer");
}

// Compile and link shaders, storing the program ID in shader array
bool initShader()
{
	string vertexSource = LoadSource("vertex.glsl");		// Put vertex file text into string
    string fragmentSource;
    if (scene == 0) {
        fragmentSource = LoadSource("fragment.glsl");	// Put fragment file text into string
    }
    if (scene == 1) {
        fragmentSource = LoadSource("fragment1.glsl");	// Put fragment file text into string
    }
    if (scene == 2) {
        fragmentSource = LoadSource("fragment2.glsl");	// Put fragment file text into string
    }
    if (scene == 3) {
        fragmentSource = LoadSource("fragment3.glsl");  // Put fragment file text into string
    }

	GLuint vertexID = CompileShader(GL_VERTEX_SHADER, vertexSource);
	GLuint fragmentID = CompileShader(GL_FRAGMENT_SHADER, fragmentSource);

	shader[SHADER::LINE] = LinkProgram(vertexID, fragmentID);	// Link and store program ID in shader array

	return !CheckGLErrors("initShader");
}

// generate a rectangle to render the image onto, and scale it so the image maintains its original aspect ratio
void generateRect(float width, float height)
{
	vec2 p00 = vec2(
		-width*0.5f,
		height*0.5f);
	vec2 uv00 = vec2(
		0.f,
		0.f);

	vec2 p01 = vec2(
		width*0.5f,
		height*0.5f);
	vec2 uv01 = vec2(
		1.f,
		0.f);

	vec2 p10 = vec2(
		-width*0.5f,
		-height*0.5f);
	vec2 uv10 = vec2(
		0.f,
		1.f);

	vec2 p11 = vec2(
		width*0.5f,
		-height*0.5f);
	vec2 uv11 = vec2(
		1.f,
		1.f);

	// Triangle 1
	points.push_back(p00);
	points.push_back(p10);
	points.push_back(p01);

	uvs.push_back(uv00);
	uvs.push_back(uv10);
	uvs.push_back(uv01);

	// Triangle 2
	points.push_back(p11);
	points.push_back(p01);
	points.push_back(p10);

	uvs.push_back(uv11);
	uvs.push_back(uv01);
	uvs.push_back(uv10);
}

bool loadUniforms()
{
    // camera mode
    GLint modeUniformLocation = glGetUniformLocation(shader[SHADER::LINE], "mode");
    glUniform1i(modeUniformLocation, mode);
    // camera 1 position
    GLint cam1UniformLocation = glGetUniformLocation(shader[SHADER::LINE], "cam1Origin");
    glUniform3f(cam1UniformLocation, cam1Origin.x, cam1Origin.y, cam1Origin.z);

    // camera 2 position
    GLint cam2UniformLocation = glGetUniformLocation(shader[SHADER::LINE], "cam2Origin");
    glUniform3f(cam2UniformLocation, cam2Origin.x, cam2Origin.y, cam2Origin.z);

    // camera offset
    GLint offsetUniformLocation = glGetUniformLocation(shader[SHADER::LINE], "offset");
    glUniform1f(offsetUniformLocation, offset);

    // camera field of view
    GLint fovUniformLocation = glGetUniformLocation(shader[SHADER::LINE], "fov");
    glUniform1f(fovUniformLocation, fov);

    // anti-aliasing
    GLint AAUniformLocation = glGetUniformLocation(shader[SHADER::LINE], "AA");
    glUniform1i(AAUniformLocation, AA);

    // timey parameter
    GLint timeyUniformLocation = glGetUniformLocation(shader[SHADER::LINE], "timey");
    glUniform1f(timeyUniformLocation, timey);

    // stimey parameter
    GLint stimeyUniformLocation = glGetUniformLocation(shader[SHADER::LINE], "stimey");
    glUniform1i(stimeyUniformLocation, stimey);

	return !CheckGLErrors("loadUniforms");
}

void key_callback(GLFWwindow* window, int key, int scancode, int action, int mods)
{
    if (key == GLFW_KEY_ESCAPE && action == GLFW_PRESS) {
        glfwSetWindowShouldClose(window, GL_TRUE);
    }
    if (key == GLFW_KEY_SPACE && action == GLFW_PRESS) {
        mode += 1;
        mode %= 2;
    }
    if (key == GLFW_KEY_1 && action == GLFW_PRESS) {
        scene = 0;
        initShader();
    }
    if (key == GLFW_KEY_2 && action == GLFW_PRESS) {
        scene = 1;
        initShader();
    }
    if (key == GLFW_KEY_3 && action == GLFW_PRESS) {
        scene = 2;
        initShader();
    }
    if (key == GLFW_KEY_4 && action == GLFW_PRESS) {
        scene = 3;
        initShader();
    }
    if (key == GLFW_KEY_F && action == GLFW_PRESS) {
        AA = !AA;
    }
    if (key == GLFW_KEY_EQUAL && action == GLFW_PRESS) {
        fov += 5;
    }
    if (key == GLFW_KEY_MINUS && action == GLFW_PRESS) {
        fov -= 5;
    }
    if (key == GLFW_KEY_LEFT && action == GLFW_PRESS) {
        fov = 60;
        t = 0;
        cameraMode--;
        if (cameraMode < 0)
            cameraMode++;
    }
    if (key == GLFW_KEY_RIGHT && action == GLFW_PRESS) {
        fov = 60;
        t = 0;
        cameraMode++;
        if (cameraMode > 2)
            cameraMode--;

    }
    if (key == GLFW_KEY_A) {
        pos.x -= delta;
    }
    if (key == GLFW_KEY_D) {
        pos.x += delta;
    }
    if (key == GLFW_KEY_W) {
        pos.z -= delta;
    }
    if (key == GLFW_KEY_S) {
        pos.z += delta;
    }
    if (key == GLFW_KEY_UP) {
        pos.y += delta;
    }
    if (key == GLFW_KEY_DOWN) {
        pos.y -= delta;
    }
    loadUniforms();
    loadBuffer(points, uvs);
}

// Initialization
void initGL()
{
	// Only call these once - don't call again every time you change geometry
	generateIDs();		// Create VertexArrayObjects and Vertex Buffer Objects and store their handles
	initShader();		// Create shader and store program ID

	initVAO();			// Describe setup of Vertex Array Objects and Vertex Buffer Objects

    // Call these two every time you change geometry (spoiler alert, you never will)
	generateRect(2.f, 2.f);
	loadBuffer(points, uvs);	// Load geometry into buffers
}


// Draws buffers to screen
void render()
{
	glClearColor(0.f, 0.f, 0.f, 0.f);		// Color to clear the screen with (R, G, B, Alpha)
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);		// Clear color and depth buffers (Haven't covered yet)

	// Don't need to call these on every draw, so long as they don't change
	glUseProgram(shader[SHADER::LINE]);		// Use LINE program
	glBindVertexArray(vao[VAO::LINES]);		// Use the LINES vertex array

    // camOrigin = vec3(2*sin(t), 2*cos(t), 0.0);

    if (mode == 0)
        offset = 0.0;
    if (mode == 1)
        offset = 0.01;

    // normal camera mode
    if (cameraMode == 0) {
        cam1Origin = pos + vec3(-offset, 0.0, 0.0);
        cam2Origin = pos + vec3(offset, 0.0, 0.0);
    }

    // circular camera mode
    if (cameraMode == 1) {
        cam1Origin = pos + vec3(2*sin(t) - offset, 0.0, 2*cos(t));
        cam2Origin = pos + vec3(2*sin(t) + offset, 0.0, 2*cos(t));
    }
    // wacky camera mode
    if (cameraMode == 2) {
        cam1Origin = pos + vec3(-offset, 0.0, -3*sin(t));
        cam2Origin = pos + vec3(offset, 0.0, -3*sin(t));
        fov = 40*(sin(t)+1) + 20;
    }

    t += (5 * PI / 180);
    stimey += 5;
    stimey %= 360;
    if (scene == 2)
      timey  = (sin((t/2)-(PI/2)) + 1)/2;
    else
      timey = (sin((t)-(PI/2)) + 1)/2;

    // load 'em
	loadUniforms();

	glDrawArrays(
			GL_TRIANGLES,		// What shape we're drawing	- GL_TRIANGLES, GL_LINES, GL_POINTS, GL_QUADS, GL_TRIANGLE_STRIP
			0,						// Starting index
			points.size()		// How many vertices
			);

	CheckGLErrors("render");
}




// ==========================================================================
// PROGRAM ENTRY POINT

int main(int argc, char *argv[])
{
    // initialize the GLFW windowing system
    if (!glfwInit()) {
        cout << "ERROR: GLFW failed to initilize, TERMINATING" << endl;
        return -1;
    }
    glfwSetErrorCallback(ErrorCallback);

    // attempt to create a window with an OpenGL 4.1 core profile context
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 1);
    glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
    window = glfwCreateWindow(WIDTH, HEIGHT, "CPSC 453 OpenGL Boilerplate", 0, 0);
    if (!window) {
        cout << "Program failed to create GLFW window, TERMINATING" << endl;
        glfwTerminate();
        return -1;
    }

    // set keyboard callback function and make our context current (active)
    glfwSetKeyCallback(window, key_callback);
    glfwMakeContextCurrent(window);


    // query and print out information about our OpenGL environment
    QueryGLVersion();

	initGL();

    // run an event-triggered main loop
    while (!glfwWindowShouldClose(window))
    {
        // call function to draw our scene
        render();

        // scene is rendered to the back buffer, so swap to front for display
        glfwSwapBuffers(window);

        // sleep until next event before drawing again
        glfwPollEvents();
	}

	// clean up allocated resources before exit
   deleteIDs();
	glfwDestroyWindow(window);
   glfwTerminate();

   return 0;
}

// ==========================================================================
// SUPPORT FUNCTION DEFINITIONS

// --------------------------------------------------------------------------
// OpenGL utility functions

void QueryGLVersion()
{
    // query opengl version and renderer information
    string version  = reinterpret_cast<const char *>(glGetString(GL_VERSION));
    string glslver  = reinterpret_cast<const char *>(glGetString(GL_SHADING_LANGUAGE_VERSION));
    string renderer = reinterpret_cast<const char *>(glGetString(GL_RENDERER));

    cout << "OpenGL [ " << version << " ] "
         << "with GLSL [ " << glslver << " ] "
         << "on renderer [ " << renderer << " ]" << endl;
}

bool CheckGLErrors(string location)
{
    bool error = false;
    for (GLenum flag = glGetError(); flag != GL_NO_ERROR; flag = glGetError())
    {
        cout << "OpenGL ERROR:  ";
        switch (flag) {
        case GL_INVALID_ENUM:
            cout << location << ": " << "GL_INVALID_ENUM" << endl; break;
        case GL_INVALID_VALUE:
            cout << location << ": " << "GL_INVALID_VALUE" << endl; break;
        case GL_INVALID_OPERATION:
            cout << location << ": " << "GL_INVALID_OPERATION" << endl; break;
        case GL_INVALID_FRAMEBUFFER_OPERATION:
            cout << location << ": " << "GL_INVALID_FRAMEBUFFER_OPERATION" << endl; break;
        case GL_OUT_OF_MEMORY:
            cout << location << ": " << "GL_OUT_OF_MEMORY" << endl; break;
        default:
            cout << "[unknown error code]" << endl;
        }
        error = true;
    }
    return error;
}

// --------------------------------------------------------------------------
// OpenGL shader support functions

// reads a text file with the given name into a string
string LoadSource(const string &filename)
{
    string source;

    ifstream input(filename.c_str());
    if (input) {
        copy(istreambuf_iterator<char>(input),
             istreambuf_iterator<char>(),
             back_inserter(source));
        input.close();
    }
    else {
        cout << "ERROR: Could not load shader source from file "
             << filename << endl;
    }

    return source;
}

// creates and returns a shader object compiled from the given source
GLuint CompileShader(GLenum shaderType, const string &source)
{
    // allocate shader object name
    GLuint shaderObject = glCreateShader(shaderType);

    // try compiling the source as a shader of the given type
    const GLchar *source_ptr = source.c_str();
    glShaderSource(shaderObject, 1, &source_ptr, 0);
    glCompileShader(shaderObject);

    // retrieve compile status
    GLint status;
    glGetShaderiv(shaderObject, GL_COMPILE_STATUS, &status);
    if (status == GL_FALSE)
    {
        GLint length;
        glGetShaderiv(shaderObject, GL_INFO_LOG_LENGTH, &length);
        string info(length, ' ');
        glGetShaderInfoLog(shaderObject, info.length(), &length, &info[0]);
        cout << "ERROR compiling shader:" << endl << endl;
        cout << source << endl;
        cout << info << endl;
    }

    return shaderObject;
}

// creates and returns a program object linked from vertex and fragment shaders
GLuint LinkProgram(GLuint vertexShader, GLuint fragmentShader)
{
    // allocate program object name
    GLuint programObject = glCreateProgram();

    // attach provided shader objects to this program
    if (vertexShader)   glAttachShader(programObject, vertexShader);
    if (fragmentShader) glAttachShader(programObject, fragmentShader);

    // try linking the program with given attachments
    glLinkProgram(programObject);

    // retrieve link status
    GLint status;
    glGetProgramiv(programObject, GL_LINK_STATUS, &status);
    if (status == GL_FALSE)
    {
        GLint length;
        glGetProgramiv(programObject, GL_INFO_LOG_LENGTH, &length);
        string info(length, ' ');
        glGetProgramInfoLog(programObject, info.length(), &length, &info[0]);
        cout << "ERROR linking shader program:" << endl;
        cout << info << endl;
    }

    return programObject;
}


// ==========================================================================
