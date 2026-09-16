shader_type canvas_item;
render_mode unshaded;
uniform sampler2D geography : filter_linear, repeat_disable;
uniform sampler2D grass : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D road : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D water : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D paving : source_color, filter_linear_mipmap, repeat_enable;
uniform vec2 palace_tile;
uniform float map_size=88.0;
uniform float clock=0.0;
float hash(vec2 p){ return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float meadow(vec2 p){
	vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void fragment(){
	vec2 pixel=vec2((UV.x-0.5)*map_size*64.0,UV.y*(map_size*32.0+32.0));
	vec2 tile=vec2(pixel.x/64.0+pixel.y/32.0,pixel.y/32.0-pixel.x/64.0);
	vec2 sample_uv=tile/map_size;
	vec3 land=texture(geography,sample_uv).rgb;
	vec2 grain=pixel/vec2(256.0,128.0);
	vec3 color=texture(grass,grain).rgb;
	// Broad meadow variation breaks repetition without obscuring walkable terrain.
	float field=meadow(tile*.23)*.65+meadow(tile*.61)*.35;
	color=mix(color*vec3(.84,.97,.81),color*vec3(1.08,1.08,.94),smoothstep(.15,.88,field));
	color=mix(vec3(dot(color,vec3(.299,.587,.114))),color,.87)*vec3(.94,.96,1.02);
	color=mix(color,texture(road,grain).rgb,smoothstep(0.04,0.8,land.g));
	float shore=smoothstep(0.0,0.24,land.r);
	color=mix(color,texture(dirt,grain).rgb,shore);
	vec2 ripple=vec2(sin(pixel.y*0.028+clock*0.5),cos(pixel.x*0.025+clock*0.4))*0.008;
	vec3 wet=texture(water,grain+ripple).rgb;
	wet=mix(wet,vec3(.12,.29,.31),.22);
	wet+=vec3(0.10,0.12,0.11)*pow(max(0.0,sin(pixel.x*0.08+pixel.y*0.12+clock*1.2)),22.0)*0.25;
	color=mix(color,wet,smoothstep(0.16,0.58,land.r));
	float foam=smoothstep(.18,.30,land.r)*(1.0-smoothstep(.30,.43,land.r));
	color+=vec3(.18,.19,.13)*foam*(.7+.3*sin(clock*.9+pixel.y*.06));
	float courtyard=1.0-smoothstep(2.6,3.2,length(tile-palace_tile));
	color=mix(color,texture(paving,grain).rgb,courtyard);
	// Slow, low-contrast cloud shadows add depth without hiding actors.
	float cloud=smoothstep(.38,.78,meadow(tile*.075+vec2(clock*.002,-clock*.001)));
	color*=.96-cloud*.065;
	float inside=step(0.0,tile.x)*step(0.0,tile.y)*(1.0-step(map_size,tile.x))*(1.0-step(map_size,tile.y));
	COLOR=vec4(color,inside);
}
