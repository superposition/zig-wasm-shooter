// Fragment shader for 2D rendering
// Supports solid colors via uniform

precision mediump float;

uniform vec4 u_color;

void main() {
    gl_FragColor = u_color;
}
