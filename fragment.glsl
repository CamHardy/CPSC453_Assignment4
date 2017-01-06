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
uniform int stimey;
/*uniform*/ int reflectLevels = 10;
int reflectCount = 0;

// used for anit-aliasing. This is the size of the subdivisions of each pixel
// originally planned for this to be interactive so you could choose the amount of anti-aliasing
// opengl frame rate had other ideas
float delta = 1.0/(640.0 * 4);

vec2 position1 = vec2(position.x - offset, position.y);
vec2 position2 = vec2(position.x + offset, position.y);

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

Sphere spheres[1];
Triangle triangles[12];
Plane planes[1];
PointLight pLights[2];
GlobalLight gLights[1];
float t ;
float p0;
float p1;

float deg2rad(float deg) {
    return deg * PI / 180;
}

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
    /*
     // for some reason this intersection method goes wack when the camera moves, into the bin it goes
     vec3 line1 = tri.p1 - tri.p0;
    vec3 line2 = tri.p2 - tri.p0;
    vec3 norm = crossProduct(line1, line2);
    float denominator = dotProduct(norm, norm);

    // check if the ray is parallel with the triangle surface
    float par = dotProduct(norm, ray.direction);
    if (par >= 0 && par < epsilon)
        return false;
    float d = dotProduct(norm, tri.p0);
    t = (dotProduct(norm, ray.origin) + d) / par;
    if (t < 0)
        return false;
    vec3 hitPoint = ray.origin + (t * ray.direction);
    vec3 perp;

    vec3 edge0 = tri.p1 - tri.p0;
    vec3 section0 = hitPoint - tri.p0;
    perp = crossProduct(edge0, section0);
    if (dotProduct(norm, perp) < 0)
        return false;

    vec3 edge1 = tri.p2 - tri.p1;
    vec3 section1 = hitPoint - tri.p1;
    perp = crossProduct(edge1, section1);
    if (dotProduct(norm, perp) < 0)
        return false;

    vec3 edge2 = tri.p0 - tri.p2;
    vec3 section2 = hitPoint - tri.p2;
    perp = crossProduct(edge2, section2);
    if (dotProduct(norm, perp) < 0)
        return false;

    // if you're reading this, the ray hit the triangle
    return true;
    */
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
    Ray camera3Ray;
    Ray camera4Ray;
    Ray camera5Ray;
    Ray camera6Ray;
    Ray camera7Ray;
    Ray camera8Ray;
    Ray camera9Ray;
    Ray camera10Ray;
    Ray camera11Ray;
    Ray camera12Ray;
    Ray camera13Ray;
    Ray camera14Ray;
    Ray camera15Ray;
    Ray camera16Ray;

    camera1Ray.origin = cam1Origin;
    camera2Ray.origin = cam2Origin;
    camera3Ray.origin = cam1Origin;
    camera4Ray.origin = cam2Origin;
    camera5Ray.origin = cam1Origin;
    camera6Ray.origin = cam2Origin;
    camera7Ray.origin = cam1Origin;
    camera8Ray.origin = cam2Origin;
    camera9Ray.origin = cam1Origin;
    camera10Ray.origin = cam2Origin;
    camera11Ray.origin = cam1Origin;
    camera12Ray.origin = cam2Origin;
    camera13Ray.origin = cam1Origin;
    camera14Ray.origin = cam2Origin;
    camera15Ray.origin = cam1Origin;
    camera16Ray.origin = cam2Origin;

    camera1Ray.direction =  normalize(vec3(position1.x - 3.0 * delta, position.y + 3.0 * delta, -1 / scale));
    camera2Ray.direction =  normalize(vec3(position2.x -       delta, position.y + 3.0 * delta, -1 / scale));
    camera3Ray.direction =  normalize(vec3(position1.x +       delta, position.y + 3.0 * delta, -1 / scale));
    camera4Ray.direction =  normalize(vec3(position2.x + 3.0 * delta, position.y + 3.0 * delta, -1 / scale));
    camera5Ray.direction =  normalize(vec3(position1.x - 3.0 * delta, position.y +       delta, -1 / scale));
    camera6Ray.direction =  normalize(vec3(position2.x -       delta, position.y +       delta, -1 / scale));
    camera7Ray.direction =  normalize(vec3(position1.x +       delta, position.y +       delta, -1 / scale));
    camera8Ray.direction =  normalize(vec3(position2.x + 3.0 * delta, position.y +       delta, -1 / scale));
    camera9Ray.direction =  normalize(vec3(position1.x - 3.0 * delta, position.y -       delta, -1 / scale));
    camera10Ray.direction = normalize(vec3(position2.x -       delta, position.y -       delta, -1 / scale));
    camera11Ray.direction = normalize(vec3(position1.x +       delta, position.y -       delta, -1 / scale));
    camera12Ray.direction = normalize(vec3(position2.x + 3.0 * delta, position.y -       delta, -1 / scale));
    camera13Ray.direction = normalize(vec3(position1.x - 3.0 * delta, position.y - 3.0 * delta, -1 / scale));
    camera14Ray.direction = normalize(vec3(position2.x -       delta, position.y - 3.0 * delta, -1 / scale));
    camera15Ray.direction = normalize(vec3(position1.x +       delta, position.y - 3.0 * delta, -1 / scale));
    camera16Ray.direction = normalize(vec3(position2.x + 3.0 * delta, position.y - 3.0 * delta, -1 / scale));


    if (mode == 0) {
        if (AA) {
            vec3 val1 = castRay(camera1Ray);
            vec3 val2 = castRay(camera2Ray);
            vec3 val3 = castRay(camera3Ray);
            vec3 val4 = castRay(camera4Ray);
            vec3 val5 = castRay(camera5Ray);
            vec3 val6 = castRay(camera6Ray);
            vec3 val7 = castRay(camera7Ray);
            vec3 val8 = castRay(camera8Ray);
            vec3 val9 = castRay(camera9Ray);
            vec3 val10 = castRay(camera10Ray);
            vec3 val11 = castRay(camera11Ray);
            vec3 val12 = castRay(camera12Ray);
            vec3 val13 = castRay(camera13Ray);
            vec3 val14 = castRay(camera14Ray);
            vec3 val15 = castRay(camera15Ray);
            vec3 val16 = castRay(camera16Ray);
            vec3 avg = (val1 + val2 + val3 + val4 + val5 + val6 + val7 + val8 + val9 + val10 + val11 + val12 + val13 + val14 + val15 + val16) / 16.0;
            FragmentColour = vec4(avg, 0.0);
        }
        else
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
    spheres[0] = Sphere(vec3(0.9, -1.925 + timey/4, -6.69),   // center
                        0.825,                      // radius
                        vec3(0.6),                  // color
                        0, 0.8, 0.2, 64, 1.8);           // material, Kd, Ks, n

    // blue pyramid
    triangles[0] = Triangle(vec3(-0.40, -2.75, -9.55),  // p0
                            vec3(-0.93,  0.55, -8.51),  // p1
                            vec3( 0.11, -2.75, -7.98),  // p2
                            vec3( 0.0,  0.6,  0.9),     // color
                            0, 0.8, 0.2, 256, 1.8);          // material, Kd, Ks, n
    triangles[1] = Triangle(vec3( 0.11, -2.75, -7.98),
                            vec3(-0.93,  0.55, -8.51),
                            vec3(-1.46, -2.75, -7.47),
                            vec3(0.0, 0.6, 0.9),
                            0, 0.8, 0.2, 256, 1.8);
    triangles[2] = Triangle(vec3(-1.46, -2.75, -7.47),
                            vec3(-0.93,  0.55, -8.51),
                            vec3(-1.97, -2.75, -9.04),
                            vec3(0.0, 0.6, 0.9),
                            0, 0.8, 0.2, 256, 1.8);
    triangles[3] = Triangle(vec3(-1.97, -2.75, -9.04),
                            vec3(-0.93,  0.55, -8.51),
                            vec3(-0.40, -2.75, -9.55),
                            vec3(0.0, 0.6, 0.9),
                            0, 0.8, 0.2, 256, 1.8);

    // grey ceiling
    triangles[4] = Triangle(vec3( 2.75,  2.75, -10.5),
                            vec3( 2.75,  2.75, -5.00),
                            vec3(-2.75,  2.75, -5.00),
                            vec3(0.8),
                            0, 0.5, 0.2, 16, 1.8);
    triangles[5] = Triangle(vec3(-2.75,  2.75, -10.5),
                            vec3( 2.75,  2.75, -10.5),
                            vec3(-2.75,  2.75, -5.00),
                            vec3(0.8),
                            0, 0.5, 0.2, 16, 1.8);

    // green wall on the right
    triangles[6] = Triangle(vec3( 2.75,  2.75, -5.00),
                            vec3( 2.75,  2.75, -10.5),
                            vec3( 2.75, -2.75, -10.5),
                            vec3(0.0, 1.0, 0.0),
                            0, 0.5, 0.2, 64, 1.8);
    triangles[7] = Triangle(vec3( 2.75, -2.75, -5.00),
                            vec3( 2.75,  2.75, -5.00),
                            vec3( 2.75, -2.75, -10.5),
                            vec3(0.0, 1.0, 0.0),
                            0, 0.5, 0.2, 64, 1.8);

    // red wall on the left
    triangles[8] = Triangle(vec3(-2.75, -2.75, -5.00),
                            vec3(-2.75, -2.75, -10.5),
                            vec3(-2.75,  2.75, -10.5),
                            vec3(1.0, 0.0, 0.0),
                            0, 0.5, 0.2, 64, 1.8);
    triangles[9] = Triangle(vec3(-2.75,  2.75, -5.00),
                            vec3(-2.75, -2.75, -5.00),
                            vec3(-2.75,  2.75, -10.5),
                            vec3(1.0, 0.0, 0.0),
                            0, 0.5, 0.2, 64, 1.8);

    // grey floor
    triangles[10] = Triangle(vec3( 2.75, -2.75, -5.00),
                             vec3( 2.75, -2.75, -10.5),
                             vec3(-2.75, -2.75, -10.5),
                             vec3(0.6),
                             0, 0.5, 0.2, 128, 1.8);
    triangles[11] = Triangle(vec3(-2.75, -2.75, -5.00),
                             vec3( 2.75, -2.75, -5.00),
                             vec3(-2.75, -2.75, -10.5),
                             vec3(0.6),
                             0, 0.5, 0.2, 128, 1.8);

    pLights[0] = PointLight(vec3(0.0, 2.5, -7.75),    // position
                            0.8,                    // intensity
                            vec3(0.8, 0.9, 0.98));  // color

    pLights[1] = PointLight(vec3(2.0, -1.5, -6.0),
                            0.8,
                            vec3(1.0, 0.97, 0.8));

    planes[0] = Plane(vec3(0.0, 0.0, -10.5),    // point
                      vec3(0.0, 0.0, 1.0),      // normal
                      vec3(0.8),                // color
                      0, 0.4, 0.2, 16, 1.8);         // material, Kd, Ks, n

    render();
}
