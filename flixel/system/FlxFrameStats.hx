package flixel.system;

#if cpp
@:headerCode('#include <chrono>')
#end
class FlxFrameStats
{
	public static var enabled:Bool = true;

	public static var updateMS:Float = 0;
	public static var drawMS:Float = 0;
	public static var renderMS:Float = 0;
	public static var totalMS:Float = 0;

	public static var periodMS:Float = 0;
	public static var drawCalls:Int = 0;
	public static var frameCount:Int = 0;

	// Float milliseconds with true sub-ms precision. Lib.getTimer() is whole ms, and on
	// this toolchain haxe.Timer.stamp() also quantises to 1 ms — both make p50/p99 useless
	// at high refresh. Use QueryPerformanceCounter on Windows, stamp() elsewhere.
	// std::chrono::high_resolution_clock maps to QPC on MSVC, without dragging in
	// <windows.h> (whose macros collide with OpenFL headers).
	#if cpp
	@:functionCode('
		static const auto _rainy_t0 = std::chrono::high_resolution_clock::now();
		auto _rainy_now = std::chrono::high_resolution_clock::now();
		return std::chrono::duration<double, std::milli>(_rainy_now - _rainy_t0).count();
	')
	static function hrMS():Float return 0;

	inline static function nowMS():Float
		return hrMS();
	#else
	inline static function nowMS():Float
		return haxe.Timer.stamp() * 1000.0;
	#end

	static var _updateT0:Float = 0;
	static var _drawT0:Float = 0;
	static var _renderT0:Float = 0;
	static var _frameT0:Float = 0;
	static var _prevFrameT0:Float = -1;
	static var _updateAccum:Float = 0;
	static var _drawAccum:Float = 0;
	static var _renderAccum:Float = 0;

	static inline var SAMPLE_COUNT = 512;

	static var _updateSamples:Array<Float> = [];
	static var _drawSamples:Array<Float> = [];
	static var _renderSamples:Array<Float> = [];
	static var _totalSamples:Array<Float> = [];
	static var _periodSamples:Array<Float> = [];
	static var _drawCallSamples:Array<Int> = [];
	static var _sampleIndex:Int = 0;
	static var _sampleCount:Int = 0;

	static var _scratch:Array<Float> = [];

	public static function beginFrame():Void
	{
		// Outside the `enabled` guard on purpose: the counter is read by callers that do not
		// care whether timing collection is on, and leaving it to accumulate turns a
		// per-frame number into a since-boot one.
		flixel.graphics.tile.FlxDrawBaseItem.drawCalls = 0;

		if (!enabled)
			return;
		_frameT0 = nowMS();
		periodMS = (_prevFrameT0 < 0) ? 0 : (_frameT0 - _prevFrameT0);
		_prevFrameT0 = _frameT0;
		_updateAccum = 0;
		_drawAccum = 0;
		_renderAccum = 0;
	}

	public static function beginUpdate():Void
	{
		if (!enabled)
			return;
		_updateT0 = nowMS();
	}

	public static function endUpdate():Void
	{
		if (!enabled)
			return;
		_updateAccum += nowMS() - _updateT0;
	}

	public static function beginDraw():Void
	{
		if (!enabled)
			return;
		_drawT0 = nowMS();
	}

	public static function endDraw():Void
	{
		if (!enabled)
			return;
		_drawAccum += nowMS() - _drawT0;
	}

	public static function beginRender():Void
	{
		if (!enabled)
			return;
		_renderT0 = nowMS();
	}

	public static function endRender():Void
	{
		if (!enabled)
			return;
		_renderAccum += nowMS() - _renderT0;
	}

	public static function endFrame(drawCalls:Int):Void
	{
		if (!enabled)
			return;
		updateMS = _updateAccum;
		drawMS = _drawAccum;
		renderMS = _renderAccum;
		totalMS = nowMS() - _frameT0;
		FlxFrameStats.drawCalls = drawCalls;
		frameCount++;

		_updateSamples[_sampleIndex] = updateMS;
		_drawSamples[_sampleIndex] = drawMS;
		_renderSamples[_sampleIndex] = renderMS;
		_totalSamples[_sampleIndex] = totalMS;
		_periodSamples[_sampleIndex] = periodMS;
		_drawCallSamples[_sampleIndex] = drawCalls;

		_sampleIndex = (_sampleIndex + 1) % SAMPLE_COUNT;
		if (_sampleCount < SAMPLE_COUNT)
			_sampleCount++;
	}

	public static function reset():Void
	{
		_sampleIndex = 0;
		_sampleCount = 0;
		updateMS = 0;
		drawMS = 0;
		renderMS = 0;
		totalMS = 0;
		periodMS = 0;
		// Without this the first period after a reset spans from the last measured frame to
		// now — minutes if timing was disabled in between — and p99 reports that as a hitch.
		_prevFrameT0 = -1;
	}

	public static function percentileUpdate(p:Float):Float
	{
		return percentile(_updateSamples, _sampleCount, p);
	}

	/** Highest draw-phase sample in the current window. */
	public static function maxDraw():Float
	{
		var max = 0.0;
		for (i in 0..._sampleCount)
		{
			if (_drawSamples[i] > max)
				max = _drawSamples[i];
		}
		return max;
	}

	public static function maxPeriod():Float
	{
		var max = 0.0;
		for (i in 0..._sampleCount)
		{
			if (_periodSamples[i] > max)
				max = _periodSamples[i];
		}
		return max;
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

	public static function percentilePeriod(p:Float):Float
	{
		return percentile(_periodSamples, _sampleCount, p);
	}

	public static function copyPeriodSamples():Array<Float>
	{
		var out:Array<Float> = [];
		for (i in 0..._sampleCount)
		{
			var v:Float = _periodSamples[i];
			if (v > 0) out.push(v);
		}
		return out;
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
