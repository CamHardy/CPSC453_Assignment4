#include "glm/glm.hpp"
#define PI 3.141592653589793238462643383

using namespace std;
using namespace glm;

float deg2rad(float deg) {
    return deg * PI / 180;
}

// put all those wacky linear algebraic equations here, mmkay?
float dotProduct(vec3 a, vec3 b) {
    return (float)((a.x * b.x) + (a.y * b.y) + (a.z * b.z));
}

vec3 crossProduct(vec3 a, vec3 b) {
    return vec3((a.y * b.z) - (a.z * b.y), (a.z * b.x) - (a.x * b.z), (a.x * b.y) - (a.y * b.x));
}

float norm(vec3 a) {
    return (a.x * a.x) + (a.y * a.y) + (a.z * a.z);
}

float length(vec3 a) {
    return sqrt(norm(a));
}

vec3 normalize(vec3 a) {
    float n = norm(a);
    if (n > 0) {
        float w = 1 / sqrt(n);
        a.x *= w;
        a.y *= w;
        a.z *= w;
    }
    return a;
}

bool quadratic(float a, float b, float c, float &p0, float &p1) {
    // y'all know the quadratic formula, yes?
    float discriminant = b * b - 4 * a * c;
    if (discriminant < 0)
        return false; // ain't nobody got time for imaginary numbers!
    p0 = (b + sqrt(discriminant)) / (-2 * a);
    p1 = (b - sqrt(discriminant)) / (-2 * a);
    return true;
}