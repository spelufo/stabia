#version 420 core

uniform float time;
uniform vec3 dimensions;
uniform vec3 cellp0;
uniform vec3 cellp1;
uniform int style;
uniform vec4 clipplane;

uniform vec3 cam;
uniform mat4 view;
uniform mat4 proj;

////////////////////////////////////////////////////////////////////////////////
// Vertex shader
#line 15

layout (location = 0) in vec3 v_P;
out vec3 P;
out vec3 Ray;


void main() {
  P = v_P;
  vec4 p = vec4(P, 1.0);
  gl_Position = proj * view * p;
  gl_ClipDistance[0] = -dot(p, clipplane);
  Ray = P - cam;
}

////////////////////////////////////////////////////////////////////////////////
// Fragment shader
#line 31

in vec3 P;
in vec3 N;
in vec2 T;
in vec3 Ray;

uniform usampler3D Small;
uniform usampler3D Cell;

uniform vec3 SmallScale;
uniform vec3 CellScale;

out vec4 FragColor;

// vis: Visual output debugging. Example usage: `vis(SS); return;`.
void vis(float A) { FragColor = vec4(A, A, A, 1); }
void vis(vec2  A) { FragColor = vec4(A, 0, 1); }
void vis(vec3  A) { FragColor = vec4(A, 1); }

// vec3 colormap(float ahit) {
//   vec3 A = vec3(0.0);
//   if (ahit > 0.99) A = max(A, 5*ahit*vec3(1,0,0));
//   else if (ahit > 0.80) A += 5*ahit*vec3(1,0,1);
//   // else if (ahit > 0.70) A += 15*ahit*vec3(1,1,0);
//   // else if (ahit > 0.50) A += ahit*vec3(0,0,0);
//   // else if (ahit > 0.40) A += ahit*vec3(0,0,0);
//   // else if (ahit > 0.30) A += ahit*vec3(0,0,0);
//   // else if (ahit > 0.20) A += ahit*vec3(0,0,0);
//   return A;
// }

vec3 colormap(float ahit) {
  vec3 A = vec3(0.0);
  if (ahit > 0.508) A += vec3(0,0,0);
  else if (ahit > 0.4) A += 2*ahit*vec3(1,0,0);
  else if (ahit > 0.35) A += 4*ahit*vec3(0,1,1);
  // else if (ahit > 0.273) A += 8*ahit*vec3(0,1,1);
  // else if (ahit > 0.50) A += ahit*vec3(0,0,0);
  // else if (ahit > 0.40) A += ahit*vec3(0,0,0);
  // else if (ahit > 0.30) A += ahit*vec3(0,0,0);
  // else if (ahit > 0.20) A += ahit*vec3(0,0,0);
  return A;
}


float measure(vec3 p) {
  float d = 0.01;
  return float(
    (p.x > cellp0.x-d && p.x < cellp1.x+d &&
     p.y > cellp0.y-d && p.y < cellp1.y+d &&
     p.z > cellp0.z-d && p.z < cellp1.z+d) ?
    texture(Cell, 0.99999*CellScale*(p-cellp0)/(cellp1 - cellp0)).r :
    texture(Small, 0.99999*SmallScale*p/dimensions).r
    ) / 65535.0;
}

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

void main() {
  vec3 ray = normalize(P - cam);
  // vis(measure(P)); return;
  if (style == 0) {
    vis(measure(P)); return;
    // vec3 ray = normalize(P - cam);
  }
  // t: Time.
  float t = time;

  // A: Amplitude of the output color.
  vec3 A = vec3(0);
  float a = 0.0;

  vec3 p = P;// - vec3(0, 60*(0.5+0.5*sin(1.1)), 0);
  int nsteps = 20;
  float l = 10;
  float lstep = l/nsteps;
  float dd = 0.00791/4;
  p += 10*ray;
  for (int i = 0; i < nsteps; i++) {
    if (p.z < 0.00 || p.z > dimensions.z+0.001) break;
    if (p.x < 0.00 || p.x > dimensions.x+0.001) break;
    if (p.y < 0.00 || p.y > dimensions.y+0.001) break;
    float ahit = measure(p);
    A += colormap(ahit)/nsteps;
    // float ahit_l = measure(p-dd*vec3(1,0,0));
    // float ahit_r = measure(p+dd*vec3(1,0,0));
    // float ahit_u = measure(p-dd*vec3(0,1,0));
    // float ahit_d = measure(p+dd*vec3(0,1,0));
    // float ahit_a = measure(p-dd*vec3(0,0,1));
    // float ahit_b = measure(p+dd*vec3(0,0,1));
    // float nhitx = (-1/((ahit_r-ahit)/dd) + -1/((ahit-ahit_l)/dd))/2;
    // float nhity = (-1/((ahit_u-ahit)/dd) + -1/((ahit-ahit_d)/dd))/2;
    // float nhitz = (-1/((ahit_a-ahit)/dd) + -1/((ahit-ahit_b)/dd))/2;
    // vec3 nhit = normalize(vec3(nhitx, nhity, nhitz));
    // vec3 rdir = rand_dir();
    // ray = dot(rdir, nhit) < 0 ? -rdir : rdir;
    // p += dd*ray;
    p += lstep*ray;
  }
  // A.r = A.g = A.b = a;
  vis(A); return;

}
