shader_type canvas_item;
render_mode unshaded;
uniform sampler2D vision : filter_linear, repeat_disable;
uniform float map_size=88.0;
void fragment(){
	vec2 pixel=vec2((UV.x-0.5)*map_size*64.0,UV.y*(map_size*32.0+32.0));
	vec2 tile=vec2(pixel.x/64.0+pixel.y/32.0,pixel.y/32.0-pixel.x/64.0);
	vec2 fog=texture(vision,tile/map_size).rg;
	float alpha=(1.0-smoothstep(0.02,0.98,fog.r))*0.96;
	alpha=max(alpha,(1.0-smoothstep(0.0,1.0,fog.g))*0.57);
	float inside=step(0.0,tile.x)*step(0.0,tile.y)*(1.0-step(map_size,tile.x))*(1.0-step(map_size,tile.y));
	COLOR=vec4(0.045,0.060,0.054,alpha*inside);
}
