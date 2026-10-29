package flixel.text;

import flixel.graphics.frames.FlxFramesCollection;
import openfl.display.BitmapData;

typedef FlxTextPagerSlot = {
	
	var frames:FlxFramesCollection;

	
	var index:Int;
}

interface FlxTextPager
{

	function find(key:String):FlxTextPagerSlot;

	function store(key:String, source:BitmapData):FlxTextPagerSlot;
}
