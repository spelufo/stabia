#version 420 core

uniform vec3 dimensions;
uniform vec3 cellp0;
uniform vec3 cellp1;

uniform vec3 cam;
uniform mat4 model;
uniform mat4 view;
uniform mat4 proj;

////////////////////////////////////////////////////////////////////////////////
// Vertex shader
#line 15

layout (location = 0) in vec3 v_P;
out vec3 P;
out vec3 Ray;


void main() {
  vec4 p = model * vec4(v_P, 1.0);
  vec4 vp = view * p;
  gl_Position = proj * vp;
  P = p.xyz;
  Ray = vp.xyz - cam;

  // P = model * vec4(v_P, 1.0);
  // Ray = P - cam;
  // gl_Position = proj * view * P;
}

////////////////////////////////////////////////////////////////////////////////
// Fragment shader
#line 35

// Lib

float rand() {
  vec2 xy = gl_FragCoord.xy;
  float seed = 0.2;
  float PHI = 1.61803398874989484820459;
  return fract(tan(distance(xy*PHI, xy)*seed)*xy.x);
}

float rand_normal() {
    float theta = 2*3.1415926*rand();
    float rho = sqrt(-2*log(rand()));
    return rho*cos(theta);
}

vec3 rand_dir() {
  return normalize(vec3(rand_normal(), rand_normal(), rand_normal()));
}


// Shader

in vec3 P;
// in vec3 N;
// in vec2 T;
in vec3 Ray;

out vec4 FragColor;

uniform usampler3D Small;
uniform usampler3D Cell;

uniform vec3 SmallScale;
uniform vec3 CellScale;


// // vis: Visual output debugging. Example usage: `vis(SS); return;`.
void vis(float A) { FragColor = vec4(A, A, A, 1); }
void vis(vec2  A) { FragColor = vec4(A, 0, 1); }
void vis(vec3  A) { FragColor = vec4(A, 1); }

float measure(vec3 p) {
  return float(
    texture(Cell, 0.99999*CellScale*(p-cellp0)/(cellp1 - cellp0)).r
    ) / 65535.0;
}

float meas(vec3 p) {
  float v = measure(p);
  float c = 0.35;
  float g = 0.7;
  return max(0, pow((v - c)/(1.0 - c), g));
}

void main() {
  // vis(vec3(1,0,1)); return;
  // vis(meas(P)); return;
  vec3 A = vec3(0);
  vec3 N = -normalize(Ray);
  float value = 0;
  float nmerge_step = 7.91/1000;
  float offset = 0;
  value += meas(P - (offset)*N);
  A.r = value;
  value += meas(P - (offset + nmerge_step)*N);
  A.g = value/2;
  value += meas(P - (offset + 2*nmerge_step)*N);
  A.b = value/3;
  vis(A);
  // vis(1-A);
  return;
}
