// ==========================================================================
// Vertex program for barebones GLFW boilerplate
//
// Author:  Sonny Chan, University of Calgary
// Edits made by the Cameron Hardy
// Actually I pretty much re-wrote this, I'm pretty great
// Date:    2016
// ==========================================================================
#version 410

// interpolated colour received from vertex stage
in vec2 uv;
in vec2 position;

// first output is mapped to the framebuffer's colour index by default
out vec4 FragmentColour;

uniform int mode;
uniform vec3 cam1Origin;    // camera 1 origin
uniform vec3 cam2Origin;    // camera 2 origin;
uniform float offset;
uniform float fov;          // camera field of view
uniform bool AA;            // anti-aliasing
uniform float timey;
/*uniform*/ int reflectLevels = 10;
uniform int stimey;
int reflectCount = 0;

float delta = 1.0/(640.0 * 4);

float REALLYFAR = 75;
float PI = 3.141592653589793238462643383;
vec3 backgroundColor = vec3(0.0);
vec3 frame1color;
vec3 frame2color;
float epsilon = 0.00000001; // to approximate if rays are parallel to planes/triangles
float bias = 0.0001; // to prevent self-collisions

struct Ray {
    vec3 origin;
    vec3 direction;
};

struct Sphere {
    vec3 center;
    float radius;
    vec3 color;
    int material;   // 0 = phong, 1 = transparent, 2 = mirror
    float Kd;       // diffuse, refraction index, or
    float Ks;
    float n;
    float Ir;
};

struct Triangle {
    vec3 p0;
    vec3 p1;
    vec3 p2;
    vec3 color;
    int material;
    float Kd;
    float Ks;
    float n;
    float Ir;
};

struct Plane {
    vec3 point;
    vec3 normal;
    vec3 color;
    int material;
    float Kd;
    float Ks;
    float n;
    float Ir;
};

struct PointLight {
    vec3 point;
    float intensity;
    vec3 color;
};

struct GlobalLight {
    vec3 direction;
    float intensity;
    vec3 color;
};

Sphere spheres[2];
Triangle triangles[28];
Plane planes[2];
PointLight pLights[2];
GlobalLight gLights[1];
float t ;
float p0;
float p1;

float deg2rad(float deg) {
    return deg * PI / 180;
}

vec2 position1 = vec2(position.x - offset, position.y+0.1+sin(deg2rad(stimey))/6);
vec2 position2 = vec2(position.x + offset, position.y+0.1+sin(deg2rad(stimey))/6);

// put all those wacky linear algebraic equations here, mmkay?
float dotProduct(vec3 a, vec3 b) {
    return ((a.x * b.x) + (a.y * b.y) + (a.z * b.z));
}

vec3 crossProduct(vec3 a, vec3 b) {
    return vec3((a.y * b.z) - (a.z * b.y), (a.z * b.x) - (a.x * b.z), (a.x * b.y) - (a.y * b.x));
}

float langth(vec3 a) {
    return sqrt((a.x * a.x) + (a.y * a.y) + (a.z * a.z));
}

vec3 normalize(vec3 a) {
    float w = 1 / langth(a);
    a.x *= w;
    a.y *= w;
    a.z *= w;

    return a;
}

bool quadratic(float a, float b, float c) {
    // y'all know the quadratic formula, yes?
    float discriminant = (b * b) - (4 * a * c);
    if (discriminant < 0)
        return false; // ain't nobody got time for imaginary numbers!
    p0 = (b + sqrt(discriminant)) / (-2 * a);
    p1 = (b - sqrt(discriminant)) / (-2 * a);
    return true;
}

bool intersectSphere(Sphere sphere, Ray ray) {
    // time for the quadratic equation
    vec3 x = ray.origin - sphere.center;
    float a = dotProduct(ray.direction, ray.direction);
    float b = 2 * dotProduct(ray.direction, x);
    float c = dotProduct(x, x) - (sphere.radius * sphere.radius);
    bool test = quadratic(a, b, c);
    if (test == false)
        return false; // if there are no solutions, there is no intersection
    if (p0 < 0 && p1 < 0)
        return false; // we don't want negative solutions
    t = min(p0, p1);
    return true;
}

bool intersectTriangle(Triangle tri, Ray ray) {

    vec3 edge1 = tri.p1 - tri.p0;
    vec3 edge2 = tri.p2 - tri.p0;
    vec3 norm = crossProduct(ray.direction, edge2);
    float det = dotProduct(edge1, norm);

    if (abs(det) < epsilon)
        return false;

    float inverseDet = 1 / det;
    vec3 x = ray.origin - tri.p0;
    float u = dotProduct(x, norm) * inverseDet;
    if (u < 0 || u > 1)
        return false;

    vec3 y = crossProduct(x, edge1);
    float v = dotProduct(ray.direction, y) * inverseDet;
    if (v < 0 || u + v > 1)
        return false;

    t = dotProduct(edge2, y) * inverseDet;

    if (t < 0)
        return false;
    return true;
}

bool intersectPlane(Plane plane, Ray ray) {
    float denominator = dotProduct(plane.normal, ray.direction);
    vec3 x = plane.point - ray.origin;
    if (abs(denominator) < epsilon)
        return false;
    t = dotProduct(x, plane.normal) / denominator;
    if (t < 0)
        return false;
    return true;
}

vec3 getSphereNormal(Sphere sphere, vec3 pointHit) {
    vec3 normalHit = pointHit - sphere.center;
    return normalize(normalHit);
}

vec3 getTriangleNormal(Triangle tri) {
    vec3 edge1 = tri.p1 - tri.p0;
    vec3 edge2 = tri.p2 - tri.p0;
    vec3 normalHit = crossProduct(edge1, edge2);
    return normalize(normalHit);
}

vec3 getPlaneNormal(Plane plane) {
    return normalize(plane.normal);
}

vec3 reflect(vec3 dir, vec3 norm) {
  return dir - (2 * dotProduct(dir, norm) * norm);
}
float fresnel(vec3 direction, vec3 normal, float Ir) {
    float cosi = clamp(-1, 1, dotProduct(direction, normal));
    float etai = 1;
    float etat = Ir;
    if (cosi > 0) {
        float temp = etai;
        etai = etat;
        etat = temp;
    }

    float sint = etai / etat * sqrt(max(0.0, 1 - cosi * cosi));

    if (sint >= 1)
        return 1;
    else {
        float cost = sqrt(max(0.0, 1 - sint * sint));
        cosi = abs(cosi);
        float Rs = ((etat * cosi) - (etai * cost)) / ((etat * cosi) + (etai * cost));
        float Rp = ((etai * cosi) - (etat * cost)) / ((etai * cosi) + (etat * cost));
        return (Rs * Rs + Rp * Rp) / 2;
    }
}

vec3 shadeSphere (Sphere sphereHit, Ray ray, float tHit) {
  vec3 hitSpherePoint = ray.origin + ray.direction * tHit;
  vec3 hitSphereNorm = getSphereNormal(sphereHit, hitSpherePoint);
  vec3 value = vec3(1.0);
  if (sphereHit.material == 0) { // phong shading
      vec3 diffuse = vec3(0.0);
      vec3 specular = vec3(0.0);
      vec3 ambient = vec3(0.0);
      for (int x = 0; x < pLights.length(); x++) {
          vec3 lightDir = (pLights[x].point - hitSpherePoint);
          float rad2 = dotProduct(lightDir, lightDir);
          float tLhit = sqrt(rad2);
          lightDir.x /= tLhit;
          lightDir.y /= tLhit;
          lightDir.z /= tLhit;
          vec3 lightIntensity = pLights[x].color * pLights[x].intensity;// / (4.0 * PI * rad2);
          ambient += pLights[x].color * pLights[x].intensity * 0.2;

          Ray lRay = Ray(hitSpherePoint + hitSphereNorm * bias,  lightDir);

          bool occluded = false;
          //t = REALLYFAR;
          for (int a = 0; a < spheres.length(); a++) {
              if(intersectSphere(spheres[a], lRay) && t < tLhit) {
                  occluded = true;
                  tLhit = t;
              }
          }
          for (int b = 0; b < triangles.length(); b++) {
              if(intersectTriangle(triangles[b], lRay) && t < tLhit) {
                  occluded = true;
                  tLhit = t;
              }

          }
          for (int c = 0; c < planes.length(); c++) {
              if(intersectPlane(planes[c], lRay) && t < tLhit) {
                  occluded = true;
                  tLhit = t;
              }
          }

          vec3 sphereLight;
          if(occluded) {
              sphereLight = lightIntensity * (atan(tLhit * 1.5) / (PI * 0.5));
              diffuse += sphereHit.color * sphereLight * max(0.0, dotProduct(hitSphereNorm, lRay.direction));
          }
          else {
              diffuse += sphereHit.color * lightIntensity * max(0.0, dotProduct(hitSphereNorm, lRay.direction));
          vec3 reflectRay = reflect(lightDir, hitSphereNorm);
          specular += lightIntensity * pow(max(0.0, dotProduct(reflectRay, ray.direction)), sphereHit.n);
          }
      }
      value *= ambient + (diffuse * sphereHit.Kd) + (specular * sphereHit.Ks);
  }
  return value;
}

vec3 shadeTriangle (Triangle triangleHit, Ray ray, float tHit) {
  vec3 hitTriPoint = ray.origin + ray.direction * tHit;
  vec3 hitTriNorm = getTriangleNormal(triangleHit);
  vec3 value = vec3(1.0);
  if (triangleHit.material == 0) {
      vec3 diffuse = vec3(0.0);
      vec3 specular = vec3(0.0);
      vec3 ambient = vec3(0.0);
      for (int x = 0; x < pLights.length(); x++) {
          vec3 lightDir = (pLights[x].point - hitTriPoint);
          float rad2 = dotProduct(lightDir, lightDir);
          float tLhit = sqrt(rad2);
          lightDir.x /= tLhit;
          lightDir.y /= tLhit;
          lightDir.z /= tLhit;
          vec3 lightIntensity = pLights[x].color * pLights[x].intensity;// / (4.0 * PI * rad2);
          ambient += pLights[x].color * pLights[x].intensity * 0.2;

          Ray lRay = Ray(hitTriPoint + hitTriNorm * bias, lightDir);

          bool occluded = false;
          //t = REALLYFAR;
          for (int a = 0; a < spheres.length(); a++) {
              if(intersectSphere(spheres[a], lRay) && t < tLhit) {
                  occluded = true;
                  tLhit = t;
              }
          }
          for (int b = 0; b < triangles.length(); b++) {
              if(intersectTriangle(triangles[b], lRay) && t < tLhit) {
                  occluded = true;
                  tLhit = t;
              }

          }
          for (int c = 0; c < planes.length(); c++) {
              if(intersectPlane(planes[c], lRay) && t < tLhit) {
                  occluded = true;
                  tLhit = t;
              }
          }
          vec3 triLight;
          if(occluded) {
              triLight = lightIntensity * (atan(tLhit * 1.5)) / (PI * 0.5);
              diffuse += triangleHit.color * triLight * max(0.0, dotProduct(hitTriNorm, lRay.direction));
          }
          else {

          diffuse += triangleHit.color * lightIntensity * max(0.0, dotProduct(hitTriNorm, lRay.direction));
          vec3 reflectRay = reflect(lightDir, hitTriNorm);
          specular += lightIntensity * pow(max(0.0, dotProduct(reflectRay, ray.direction)), triangleHit.n);
          }
      }
      value *= ambient + (diffuse * triangleHit.Kd) + (specular * triangleHit.Ks);
  }
  return value;
}

vec3 shadePlane (Plane planeHit, Ray ray, float tHit) {
  vec3 hitPlanePoint = ray.origin + ray.direction * tHit;
  vec3 hitPlaneNorm = getPlaneNormal(planeHit);
  vec3 value = vec3(1.0);
  if (planeHit.material == 0) {
      vec3 diffuse = vec3(0.0);
      vec3 specular = vec3(0.0);
      vec3 ambient = vec3(0.0);
      for (int x = 0; x < pLights.length(); x++) {
          vec3 lightDir = (pLights[x].point - hitPlanePoint);
          float rad2 = dotProduct(lightDir, lightDir);
          float tLhit = sqrt(rad2);
          lightDir.x /= tLhit;
          lightDir.y /= tLhit;
          lightDir.z /= tLhit;
          vec3 lightIntensity = pLights[x].color * pLights[x].intensity;// / (4.0 * PI * rad2);
          ambient += pLights[x].color * pLights[x].intensity * 0.2;

          Ray lRay = Ray(hitPlanePoint + hitPlaneNorm * bias, lightDir);

          bool occluded = false;
          //t = REALLYFAR;
          for (int a = 0; a < spheres.length(); a++) {
              if(intersectSphere(spheres[a], lRay) && t < tLhit) {
                  occluded = true;
                  tLhit = t;
              }
          }
          for (int b = 0; b < triangles.length(); b++) {
              if(intersectTriangle(triangles[b], lRay) && t < tLhit) {
                  occluded = true;
                  tLhit = t;
              }

          }
          for (int c = 0; c < planes.length(); c++) {
              if(intersectPlane(planes[c], lRay) && t < tLhit) {
                  occluded = true;
                  tLhit = t;
              }
          }

          vec3 planeLight;
          if (occluded) {
            planeLight = lightIntensity * (atan(tLhit * 1.5)) / (PI * 0.5);
            diffuse += planeHit.color * planeLight * max(0.0, dotProduct(hitPlaneNorm, lRay.direction));
          }
          else {
              diffuse += planeHit.color * lightIntensity * max(0.0, dotProduct(hitPlaneNorm, lRay.direction));
          vec3 reflectRay = reflect(lightDir, hitPlaneNorm);
          specular += lightIntensity * pow(max(0.0, dotProduct(reflectRay, ray.direction)), planeHit.n);
          }
      }
      value *= ambient + (diffuse * planeHit.Kd) + (specular * planeHit.Ks);
  }
  return value;
}

vec3 reflectValue(Ray ray, float tHit, vec3 hitNormal, vec3 value, float Ir) {
    vec3 objectColor;
    vec3 hitPoint = ray.origin + ray.direction * tHit;
    float kr = fresnel(ray.direction, hitNormal, Ir);
    vec3 returnColor = value * kr;
    ray.direction = reflect(ray.direction, hitNormal);
    ray.origin = (dotProduct(ray.direction, hitNormal) < 0) ? hitPoint + hitNormal * bias : hitPoint - hitNormal * bias;
    Sphere sphereHit;
    Triangle triangleHit;
    Plane planeHit;
    int hitType = 0;
    int hitMaterial = 0;

    // begin the fake recursion
    for (/* im a little duck and i flap my wings */; reflectCount < reflectLevels; reflectCount++) {
        float tDist = REALLYFAR;

        for (int i = 0; i < spheres.length(); i++) {
            if (intersectSphere(spheres[i], ray) && t < tDist) {
                sphereHit = spheres[i];
                tDist = t;
                hitType = 1;
                hitMaterial = sphereHit.material;
                hitNormal = getSphereNormal(sphereHit, ray.origin + ray.direction * tDist);
                Ir = sphereHit.Ir;
            }
        }

        for (int j = 0; j < triangles.length(); j++) {
            if (intersectTriangle(triangles[j], ray) && t < tDist) {
                triangleHit = triangles[j];
                tDist = t;
                hitType = 2;
                hitMaterial = triangleHit.material;
                hitNormal = getTriangleNormal(triangleHit);
                Ir = triangleHit.Ir;
            }
        }

        for (int k = 0; k < planes.length(); k++) {
            if (intersectPlane(planes[k], ray) && t < tDist) {
                planeHit = planes[k];
                tDist = t;
                hitType = 3;
                hitMaterial = planeHit.material;
                hitNormal = getPlaneNormal(planeHit);
                Ir = planeHit.Ir;
            }
        }

        if (hitType == 1)
            objectColor = shadeSphere(sphereHit, ray, tDist);
        if (hitType == 2)
            objectColor = shadeTriangle(triangleHit, ray, tDist);
        if (hitType == 3)
            objectColor = shadePlane(planeHit, ray, tDist);

        if (hitMaterial == 2) {
            kr = fresnel(ray.direction, hitNormal, Ir);
            ray.direction = reflect(ray.direction, hitNormal);
            ray.origin = (dotProduct(ray.direction, hitNormal) < 0) ? hitPoint + hitNormal * bias : hitPoint - hitNormal * bias;
            returnColor += objectColor * kr;
            kr *= Ir;
            // go again
        }
        //if (hitMaterial == 1)
        //    value = refractValue(ray, tDist, hitNormal, value, Ir);

        if (value == vec3(-1.0))
            value = backgroundColor;
    }
    return value;
}

vec3 castRay(Ray ray) {
    float tHit = REALLYFAR;
    vec3 value = vec3(-1.0);
    int hitType = 0;
    int hitMaterial = 0;
    float Ir = 0.0;
    vec3 hitNormal;
    Sphere sphereHit;
    Triangle triangleHit;
    Plane planeHit;
    reflectCount = 0;

    for (int i = 0; i < spheres.length(); i++) {
        if (intersectSphere(spheres[i], ray) && t < tHit) {
            sphereHit = spheres[i];
            tHit = t;
            hitType = 1;
            hitMaterial = sphereHit.material;
            hitNormal = getSphereNormal(sphereHit, ray.origin + ray.direction * tHit);
            Ir = sphereHit.Ir;
        }
    }

    for (int j = 0; j < triangles.length(); j++) {
        if (intersectTriangle(triangles[j], ray) && t < tHit) {
            triangleHit = triangles[j];
            tHit = t;
            hitType = 2;
            hitMaterial = triangleHit.material;
            hitNormal = getTriangleNormal(triangleHit);
            Ir = triangleHit.Ir;
        }
    }

    for (int k = 0; k < planes.length(); k++) {
        if (intersectPlane(planes[k], ray) && t < tHit) {
            planeHit = planes[k];
            tHit = t;
            hitType = 3;
            hitMaterial = planeHit.material;
            hitNormal = getPlaneNormal(planeHit);
            Ir = planeHit.Ir;
        }
    }

    if (hitType == 1)
        value = shadeSphere(sphereHit, ray, tHit);

    if (hitType == 2)
        value = shadeTriangle(triangleHit, ray, tHit);

    if (hitType == 3)
        value = shadePlane(planeHit, ray, tHit);

    if (hitMaterial == 2)
        //value = reflectValue(ray, tHit, hitNormal, value, Ir);

    if (hitMaterial == 1)
        //value = refractValue(ray, tHit, hitNormal, value, Ir);

    if (value == vec3(-1.0))
        value = backgroundColor;
    return value;
}

vec3 screenBlend(vec3 a, vec3 b) {
    b.r = 0.0;
    a.g = 0.0;
    a.b = 0.0;
    return vec3(1.0 - (1.0 - a.r) * (1.0 - b.r), 1.0 - (1.0 - a.g) * (1.0 - b.g), 1.0 - (1.0 - a.b) * (1.0 - b.b));
}

void render(){
    float scale = tan(deg2rad(fov * 0.5));

    Ray camera1Ray;
    Ray camera2Ray;

    camera1Ray.origin = cam1Origin;
    camera2Ray.origin = cam2Origin;
    if (mode == 0) {
            camera1Ray.direction = normalize(vec3(position1.x, position1.y, -1/scale));
            FragmentColour = vec4(castRay(camera1Ray), 0.0);
    }
    if (mode == 1) {
        float angle = deg2rad(0.7);
        mat3 rotate2 = mat3( cos(angle), 0, sin(angle),
                             0,          1, 0,
                            -sin(angle), 0, cos(angle));
        mat3 rotate1 = mat3( cos(-angle), 0, sin(-angle),
                             0,           1, 0, 
                            -sin(-angle), 0, cos(-angle));
        camera1Ray.direction = normalize(vec3(position1.x, position.y, -1 / scale));
        camera2Ray.direction = normalize(vec3(position2.x, position.y, -1 / scale));
        camera1Ray.direction *= rotate1;
        camera2Ray.direction *= rotate2;
        FragmentColour = vec4(screenBlend(castRay(camera1Ray), castRay(camera2Ray)), 0.0);
      }
}

void main(void)
{
    // set the scene

    // grey sphere
    spheres[0] = Sphere(vec3(0.0, 7.956, -17.9),   // center
                        (timey/4)+0.75,                      // radius
                        vec3(0.8, -(timey/2) + 0.5, 0.0),                  // color
                        0, 0.8, 0.6, 256, 1.8);           // material, Kd, Ks, n

    spheres[1] = Sphere(vec3(0.0, 8.0, -18.0),
                        0.9,
                        vec3(0.98, 0.70, 0.09),
                        0, 0.8, 0.1, 2, 1.8);

    // blue pyramid
    triangles[0] = Triangle(vec3(1.0, -1.0, -5.0),  // p0
                            vec3(3.0,  -0.5, -5.0),  // p1
                            vec3(3.0, -1.0, -5.0),  // p2
                            vec3( 0.0,  0.6,  0.9),     // color
                            0, 0.8, 0.2, 128, 1.8);          // material, Kd, Ks, n

    triangles[1] = Triangle(vec3(1.0, -0.5, -5.0),  // p0
                            vec3(3.0,  -0.5, -5.0),  // p1
                            vec3(1.0, -1.0, -5.0),  // p2
                            vec3( 0.0,  0.6,  0.9),     // color
                            0, 0.8, 0.2, 128, 1.8);          // material, Kd, Ks, n

    triangles[2] = Triangle(vec3(1.0, -0.5, -5.0),
                            vec3(3.0, -0.0, -5.0),
                            vec3(3.0, -0.5, -5.0),
                            vec3(0.2, 0.6, 0.9),
                            0, 0.8, 0.2, 128, 1.8);

    triangles[3] = Triangle(vec3(1.0, -0.0, -5.0),
                            vec3(3.0, -0.0, -5.0),
                            vec3(1.0, -0.5, -5.0),
                            vec3(0.2, 0.6, 0.9),
                            0, 0.8, 0.2, 128, 1.8);

    triangles[4] = Triangle(vec3(1.0, -0.0, -5.0),
                            vec3(3.0, 0.5, -5.0),
                            vec3(3.0, -0.0, -5.0),
                            vec3(0.4, 0.6, 0.9),
                            0, 0.8, 0.2, 128, 1.8);

    triangles[5] = Triangle(vec3(1.0, 0.5, -5.0),
                            vec3(3.0, 0.5, -5.0),
                            vec3(1.0, -0.0, -5.0),
                            vec3(0.4, 0.6, 0.9),
                            0, 0.8, 0.2, 128, 1.8);

    triangles[6] = Triangle(vec3(1.0, 0.5, -5.0),
                            vec3(3.0, 1.0, -5.0),
                            vec3(3.0, 0.5, -5.0),
                            vec3(0.6, 0.6, 0.9),
                            0, 0.8, 0.2, 128, 1.8);
    triangles[7] = Triangle(vec3(1.0, 1.0, -5.0),
                            vec3(3.0, 1.0, -5.0),
                            vec3(1.0, 0.5, -5.0),
                            vec3(0.6, 0.6, 0.9),
                          0, 0.8, 0.2, 128, 1.8);
    triangles[8] = Triangle(vec3(1.0, 1.0, -5.0),
                            vec3(3.0, 1.5, -5.0),
                            vec3(3.0, 1.0, -5.0),
                            vec3(0.8, 0.6, 0.9),
                            0, 0.8, 0.2, 128, 1.8);
    triangles[9] = Triangle(vec3(1.0, 1.5, -5.0),
                            vec3(3.0, 1.5, -5.0),
                            vec3(1.0, 1.0, -5.0),
                            vec3(0.8, 0.6, 0.9),
                            0, 0.8, 0.2, 128, 1.8);

    triangles[10] = Triangle(vec3(1.0, 1.5, -5.0),
                            vec3(3.0, 2.0, -5.0),
                            vec3(3.0, 1.5, -5.0),
                            vec3(1.0, 0.6, 0.9),
                            0, 0.8, 0.2, 128, 1.8);
    triangles[11] = Triangle(vec3(1.0, 2.0, -5.0),
                            vec3(3.0, 2.0, -5.0),
                            vec3(1.0, 1.5, -5.0),
                            vec3(1.0, 0.6, 0.9),
                            0, 0.8, 0.2, 128, 1.8);


                            triangles[12] = Triangle(vec3(-3.0, -1.0, -5.0),  // p0
                                                    vec3(-1.0,  -0.5, -5.0),  // p1
                                                    vec3(-1.0, -1.0, -5.0),  // p2
                                                    vec3( 0.0,  0.6,  0.9),     // color
                                                    0, 0.8, 0.2, 128, 1.8);          // material, Kd, Ks, n

                            triangles[13] = Triangle(vec3(-3.0, -0.5, -5.0),  // p0
                                                    vec3(-1.0,  -0.5, -5.0),  // p1
                                                    vec3(-3.0, -1.0, -5.0),  // p2
                                                    vec3( 0.0,  0.6,  0.9),     // color
                                                    0, 0.8, 0.2, 128, 1.8);          // material, Kd, Ks, n

                            triangles[14] = Triangle(vec3(-3.0, -0.5, -5.0),
                                                    vec3(-1.0, -0.0, -5.0),
                                                    vec3(-1.0, -0.5, -5.0),
                                                    vec3(0.2, 0.6, 0.9),
                                                    0, 0.8, 0.2, 128, 1.8);

                            triangles[15] = Triangle(vec3(-3.0, -0.0, -5.0),
                                                    vec3(-1.0, -0.0, -5.0),
                                                    vec3(-3.0, -0.5, -5.0),
                                                    vec3(0.2, 0.6, 0.9),
                                                    0, 0.8, 0.2, 128, 1.8);

                            triangles[16] = Triangle(vec3(-3.0, -0.0, -5.0),
                                                    vec3(-1.0, 0.5, -5.0),
                                                    vec3(-1.0, -0.0, -5.0),
                                                    vec3(0.4, 0.6, 0.9),
                                                    0, 0.8, 0.2, 128, 1.8);

                            triangles[17] = Triangle(vec3(-3.0, 0.5, -5.0),
                                                    vec3(-1.0, 0.5, -5.0),
                                                    vec3(-3.0, -0.0, -5.0),
                                                    vec3(0.4, 0.6, 0.9),
                                                    0, 0.8, 0.2, 128, 1.8);

                            triangles[18] = Triangle(vec3(-3.0, 0.5, -5.0),
                                                    vec3(-1.0, 1.0, -5.0),
                                                    vec3(-1.0, 0.5, -5.0),
                                                    vec3(0.6, 0.6, 0.9),
                                                    0, 0.8, 0.2, 128, 1.8);
                            triangles[19] = Triangle(vec3(-3.0, 1.0, -5.0),
                                                    vec3(-1.0, 1.0, -5.0),
                                                    vec3(-3.0, 0.5, -5.0),
                                                    vec3(0.6, 0.6, 0.9),
                                                  0, 0.8, 0.2, 128, 1.8);
                            triangles[20] = Triangle(vec3(-3.0, 1.0, -5.0),
                                                    vec3(-1.0, 1.5, -5.0),
                                                    vec3(-1.0, 1.0, -5.0),
                                                    vec3(0.8, 0.6, 0.9),
                                                    0, 0.8, 0.2, 128, 1.8);
                            triangles[21] = Triangle(vec3(-3.0, 1.5, -5.0),
                                                    vec3(-1.0, 1.5, -5.0),
                                                    vec3(-3.0, 1.0, -5.0),
                                                    vec3(0.8, 0.6, 0.9),
                                                    0, 0.8, 0.2, 128, 1.8);

                            triangles[22] = Triangle(vec3(-3.0, 1.5, -5.0),
                                                    vec3(-1.0, 2.0, -5.0),
                                                    vec3(-1.0, 1.5, -5.0),
                                                    vec3(1.0, 0.6, 0.9),
                                                    0, 0.8, 0.2, 128, 1.8);
                            triangles[23] = Triangle(vec3(-3.0, 2.0, -5.0),
                                                    vec3(-1.0, 2.0, -5.0),
                                                    vec3(-3.0, 1.5, -5.0),
                                                    vec3(1.0, 0.6, 0.9),
                                                    0, 0.8, 0.2, 128, 1.8);

                                                    triangles[24] = Triangle(vec3(-1.0, -0.99, 0.0),
                                                                            vec3(-1.0, -0.99, -50.0),
                                                                            vec3(1.0, -0.99, 0.0),
                                                                            vec3(0.2),
                                                                            0, 0.8, 0.1, 1, 1.8);
                                                    triangles[25] = Triangle(vec3(-1.0, -0.99, -50.0),
                                                                            vec3(1.0, -0.99, -50.0),
                                                                            vec3(1.0, -0.99, 0.0),
                                                                            vec3(0.2),
                                                                            0, 0.8, 0.1, 1, 1.8);
                                                    triangles[26] = Triangle(vec3(-0.075, -0.989, 0.0),
                                                                              vec3(0.075, -0.989, 0.0),
                                                                              vec3(0.075, -0.989, -50.0),
                                                                              vec3(1.0, 1.0, 0.0),
                                                                              0, 0.8, 0.3, 8, 1.8);
                                                    triangles[27] = Triangle(vec3(-0.075, -0.989, 0.0),
                                                                              vec3(0.075, -0.989, -50.0),
                                                                              vec3(-0.075, -0.989, -50.0),
                                                                              vec3(1.0, 1.0, 0.0),
                                                                              0, 0.8, 0.3, 8, 1.8);

    pLights[0] = PointLight(vec3(0.0, 2.5, -6.5),    // position
                            0.8,                    // intensity
                            vec3(0.8, 0.9, 0.98));  // color

    pLights[1] = PointLight(vec3(0.0, 12.0, -24.0),
                            timey,
                            vec3(0.97, 0.79, 0.27));

    planes[0] = Plane(vec3(0.0, 0.0, -25.5),    // point
                      vec3(0.0, 0.0, 1.0),      // normal
                      vec3(0.98, 0.09, 0.92),                // color
                      0, 0.8, 0.2, 16, 1.8);         // material, Kd, Ks, n
    planes[1] = Plane(vec3(0.0, -1.0, 0.0),
                      vec3(0.0, 1.0, 0.0),
                      vec3(0.7),
                      0, 0.6, 0.2, 16, 1.8);

    render();
}
