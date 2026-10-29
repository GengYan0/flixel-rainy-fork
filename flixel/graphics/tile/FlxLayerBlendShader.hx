package flixel.graphics.tile;

import openfl.display.Shader;

class FlxLayerBlendShader extends Shader
{
	@:glVertexSource('
		attribute vec4 openfl_Position;
		attribute vec2 openfl_TextureCoord;

		varying vec2 openfl_TextureCoordv;

		uniform mat4 openfl_Matrix;

		void main(void)
		{
			openfl_TextureCoordv = openfl_TextureCoord;
			gl_Position = openfl_Matrix * openfl_Position;
		}')
	@:glFragmentSource('
		varying vec2 openfl_TextureCoordv;

		uniform sampler2D bitmap;

		uniform sampler2D uFront;
		uniform int uMode;

		float flxLuma(vec3 c)
		{
			return dot(c, vec3(0.3, 0.59, 0.11));
		}

		float flxSat(vec3 c)
		{
			return max(max(c.r, c.g), c.b) - min(min(c.r, c.g), c.b);
		}

		vec3 flxClipColor(vec3 c)
		{
			float l = flxLuma(c);
			float n = min(min(c.r, c.g), c.b);
			float x = max(max(c.r, c.g), c.b);

			if (n < 0.0)
				c = l + (c - l) * l / (l - n);

			if (x > 1.0)
				c = l + (c - l) * (1.0 - l) / (x - l);

			return c;
		}

		vec3 flxSetLum(vec3 c, float l)
		{
			return flxClipColor(c + (l - flxLuma(c)));
		}

		vec3 flxSetSat(vec3 c, float s)
		{
			float mn = min(min(c.r, c.g), c.b);
			float mx = max(max(c.r, c.g), c.b);
			float md = c.r + c.g + c.b - mn - mx;
			float d = mx - mn;

			float nmid = d > 0.0 ? (md - mn) * s / d : 0.0;
			float nmax = d > 0.0 ? s : 0.0;

			vec3 o;
			o.r = c.r <= mn ? 0.0 : (c.r >= mx ? nmax : nmid);
			o.g = c.g <= mn ? 0.0 : (c.g >= mx ? nmax : nmid);
			o.b = c.b <= mn ? 0.0 : (c.b >= mx ? nmax : nmid);
			return o;
		}

		float flxDodge(float cb, float cs)
		{
			if (cb <= 0.0) return 0.0;
			if (cs >= 1.0) return 1.0;
			return min(1.0, cb / (1.0 - cs));
		}

		float flxBurn(float cb, float cs)
		{
			if (cb >= 1.0) return 1.0;
			if (cs <= 0.0) return 0.0;
			return 1.0 - min(1.0, (1.0 - cb) / cs);
		}

		float flxSoftLight(float cb, float cs)
		{
			float d = cb <= 0.25 ? ((16.0 * cb - 12.0) * cb + 4.0) * cb : sqrt(cb);
			return cs <= 0.5 ? cb - (1.0 - 2.0 * cs) * cb * (1.0 - cb) : cb + (2.0 * cs - 1.0) * (d - cb);
		}

		vec3 flxBlend(vec3 cb, vec3 cs)
		{
			if (uMode == 1)
				return vec3(flxDodge(cb.r, cs.r), flxDodge(cb.g, cs.g), flxDodge(cb.b, cs.b));

			if (uMode == 2)
				return vec3(flxBurn(cb.r, cs.r), flxBurn(cb.g, cs.g), flxBurn(cb.b, cs.b));

			if (uMode == 3)
				return vec3(flxSoftLight(cb.r, cs.r), flxSoftLight(cb.g, cs.g), flxSoftLight(cb.b, cs.b));

			if (uMode == 4)
				return flxSetLum(flxSetSat(cs, flxSat(cb)), flxLuma(cb));

			if (uMode == 5)
				return flxSetLum(flxSetSat(cb, flxSat(cs)), flxLuma(cb));

			if (uMode == 6)
				return flxSetLum(cs, flxLuma(cb));

			return flxSetLum(cb, flxLuma(cs));
		}

		void main()
		{
			vec2 uv = openfl_TextureCoordv;
			vec4 back = texture2D(bitmap, uv);
			vec4 front = texture2D(uFront, uv);

			vec3 cb = back.a > 0.0001 ? back.rgb / back.a : vec3(0.0);
			vec3 cs = front.a > 0.0001 ? front.rgb / front.a : vec3(0.0);

			vec3 blended = flxBlend(clamp(cb, 0.0, 1.0), clamp(cs, 0.0, 1.0));

			float ab = back.a;
			float as = front.a;

			vec3 co = as * (1.0 - ab) * cs + as * ab * blended + (1.0 - as) * ab * cb;
			float ao = as + ab * (1.0 - as);
			vec3 rgb = ao > 0.0001 ? co / ao : vec3(0.0);

			gl_FragColor = vec4(rgb * ao, ao);
		}')
	public function new()
	{
		super();
	}
}
