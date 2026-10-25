package flixel.text;

import flixel.graphics.frames.FlxFramesCollection;
import openfl.display.BitmapData;

/**
 * One label's slot in a shared texture page.
 */
typedef FlxTextPagerSlot = {
	/**
	 * Frame collection that owns the page texture.
	 */
	var frames:FlxFramesCollection;

	/**
	 * Index of this label inside `frames`.
	 */
	var index:Int;
}

interface FlxTextPager
{

	function find(key:String):FlxTextPagerSlot;

	function store(key:String, source:BitmapData):FlxTextPagerSlot;
}
