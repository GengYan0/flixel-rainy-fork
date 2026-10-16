package flixel.system;

import openfl.Lib;

class FlxFrameStats
{
	public static var enabled:Bool = true;

	public static var updateMS:Float = 0;
	public static var drawMS:Float = 0;
	public static var renderMS:Float = 0;
	public static var totalMS:Float = 0;
	public static var drawCalls:Int = 0;
	public static var frameCount:Int = 0;

	static var _updateT0:Int = 0;
	static var _drawT0:Int = 0;
	static var _renderT0:Int = 0;
	static var _frameT0:Int = 0;
	static var _updateAccum:Float = 0;
	static var _drawAccum:Float = 0;
	static var _renderAccum:Float = 0;

	static inline var SAMPLE_COUNT = 512;

	static var _updateSamples:Array<Float> = [];
	static var _drawSamples:Array<Float> = [];
	static var _renderSamples:Array<Float> = [];
	static var _totalSamples:Array<Float> = [];
	static var _drawCallSamples:Array<Int> = [];
	static var _sampleIndex:Int = 0;
	static var _sampleCount:Int = 0;

	static var _scratch:Array<Float> = [];

	public static function beginFrame():Void
	{
		if (!enabled)
			return;
		_frameT0 = Lib.getTimer();
		_updateAccum = 0;
		_drawAccum = 0;
		_renderAccum = 0;
	}

	public static function beginUpdate():Void
	{
		if (!enabled)
			return;
		_updateT0 = Lib.getTimer();
	}

	public static function endUpdate():Void
	{
		if (!enabled)
			return;
		_updateAccum += Lib.getTimer() - _updateT0;
	}

	public static function beginDraw():Void
	{
		if (!enabled)
			return;
		_drawT0 = Lib.getTimer();
	}

	public static function endDraw():Void
	{
		if (!enabled)
			return;
		_drawAccum += Lib.getTimer() - _drawT0;
	}

	public static function beginRender():Void
	{
		if (!enabled)
			return;
		_renderT0 = Lib.getTimer();
	}

	public static function endRender():Void
	{
		if (!enabled)
			return;
		_renderAccum += Lib.getTimer() - _renderT0;
	}

	public static function endFrame(drawCalls:Int):Void
	{
		if (!enabled)
			return;
		updateMS = _updateAccum;
		drawMS = _drawAccum;
		renderMS = _renderAccum;
		totalMS = Lib.getTimer() - _frameT0;
		FlxFrameStats.drawCalls = drawCalls;
		frameCount++;

		_updateSamples[_sampleIndex] = updateMS;
		_drawSamples[_sampleIndex] = drawMS;
		_renderSamples[_sampleIndex] = renderMS;
		_totalSamples[_sampleIndex] = totalMS;
		_drawCallSamples[_sampleIndex] = drawCalls;

		_sampleIndex = (_sampleIndex + 1) % SAMPLE_COUNT;
		if (_sampleCount < SAMPLE_COUNT)
			_sampleCount++;
	}

	public static function percentileUpdate(p:Float):Float
	{
		return percentile(_updateSamples, _sampleCount, p);
	}

	public static function percentileDraw(p:Float):Float
	{
		return percentile(_drawSamples, _sampleCount, p);
	}

	public static function percentileRender(p:Float):Float
	{
		return percentile(_renderSamples, _sampleCount, p);
	}

	public static function percentileTotal(p:Float):Float
	{
		return percentile(_totalSamples, _sampleCount, p);
	}

	public static function maxTotal():Float
	{
		var max = 0.0;
		for (i in 0..._sampleCount)
		{
			if (_totalSamples[i] > max)
				max = _totalSamples[i];
		}
		return max;
	}

	static function percentile(samples:Array<Float>, count:Int, p:Float):Float
	{
		if (count == 0)
			return 0;
		_scratch.resize(0);
		for (i in 0...count)
			_scratch.push(samples[i]);
		_scratch.sort(sortAscending);
		var index = Std.int(p * (count - 1) + 0.5);
		if (index < 0)
			index = 0;
		if (index >= count)
			index = count - 1;
		return _scratch[index];
	}

	static function sortAscending(a:Float, b:Float):Int
	{
		return a < b ? -1 : (a > b ? 1 : 0);
	}
}
