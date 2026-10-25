package flixel.util;

import openfl.display.BlendMode;

class FlxLayerBlend
{
	public static inline var NONE:Int = 0;
	public static inline var COLOR_DODGE:Int = 1;
	public static inline var COLOR_BURN:Int = 2;
	public static inline var SOFT_LIGHT:Int = 3;
	public static inline var HUE:Int = 4;
	public static inline var SATURATION:Int = 5;
	public static inline var COLOR:Int = 6;
	public static inline var LUMINOSITY:Int = 7;

	inline public static function modeId(?blend:BlendMode):Int
	{
		if (blend == null)
			return NONE;

		if (blend == BlendMode.COLOR_DODGE)
			return COLOR_DODGE;
		if (blend == BlendMode.COLOR_BURN)
			return COLOR_BURN;
		if (blend == BlendMode.SOFT_LIGHT)
			return SOFT_LIGHT;
		if (blend == BlendMode.HUE)
			return HUE;
		if (blend == BlendMode.SATURATION)
			return SATURATION;
		if (blend == BlendMode.COLOR)
			return COLOR;
		if (blend == BlendMode.LUMINOSITY)
			return LUMINOSITY;

		return NONE;
	}

	inline public static function needsLayer(?blend:BlendMode):Bool
	{
		return modeId(blend) != NONE;
	}

	public static function name(id:Int):String
	{
		return switch (id)
		{
			case COLOR_DODGE: 'color dodge';
			case COLOR_BURN: 'color burn';
			case SOFT_LIGHT: 'soft light';
			case HUE: 'hue';
			case SATURATION: 'saturation';
			case COLOR: 'color';
			case LUMINOSITY: 'luminosity';
			default: 'normal';
		}
	}
}
