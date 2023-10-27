#version 420 core

uniform vec3 dimensions;
uniform vec3 cellp0;
uniform vec3 cellp1;
uniform int style;

uniform vec3 cam;
uniform mat4 model;
uniform mat4 view;
uniform mat4 proj;

////////////////////////////////////////////////////////////////////////////////
// Vertex shader
#line 16

layout (location = 0) in vec3 v_P;
out vec3 P;
out vec3 Ray;


void main() {
  vec4 p = model * vec4(v_P, 1.0);
  vec4 vp = view * p;
  gl_Position = proj * vp;
  P = p.xyz;
  Ray = vp.xyz - cam;
}

////////////////////////////////////////////////////////////////////////////////
// Fragment shader
#line 33

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
uniform sampler3D CellN;

uniform vec3 SmallScale;
uniform vec3 CellScale;


// // vis: Visual output debugging. Example usage: `vis(SS); return;`.
void vis(float A) { FragColor = vec4(A, A, A, 1); }
void vis(vec2  A) { FragColor = vec4(A, 0, 1); }
void vis(vec3  A) { FragColor = vec4(A, 1); }

float measure(vec3 p) {
  // NOTE: Swizzled xy -> yz to match the texture seen on blender.
  // Probably needed to compensate from a texture layout mismatch with GL.
  return float(texture(Cell, ((p-cellp0)/(cellp1 - cellp0)).yxz).r) / 65535.0;
}

float meas(vec3 p) {
  float v = measure(p);
  float c = 0.35;
  float g = 0.7;
  return max(0, pow((v - c)/(1.0 - c), g));
}

vec3 measure_normal(vec3 p) {
  return texture(CellN, ((p-cellp0)/(cellp1 - cellp0)).yxz).rgb;
}

vec3 meas_normal(vec3 p) {
  vec3 v = measure_normal(p);
  float g = 0.4;
  float M = 40;
  float x = max(0, pow(abs(v.x)/M, g));
  float y = max(0, pow(abs(v.y)/M, g));
  float z = max(0, pow(abs(v.z)/M, g));
  return vec3(x,y,z);
}

void main() {
  if (style == 1) {
    vis(meas(P));

  } else if (style == 2) {
    vis(length(measure_normal(P)/20)); return;
    float a = measure(P);
    vec3 A = vec3(a);
    if (a > 0.35) {
      A *= 0.5 + 0.5*meas_normal(P);
    }
    vis(A);

  } else if (style == 3) {
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

  } else {
    vis(vec3(1,0,1));

  }
  // vis(1-A);
  return;
}
