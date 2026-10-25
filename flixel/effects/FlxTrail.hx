package flixel.effects;

import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.system.FlxAssets.FlxGraphicAsset;

class FlxTrail extends FlxTypedGroup<FlxSprite>
{

	public var delay:Float = 0;

	public var finish:Bool = false;

	var _sprite:FlxSprite;
	var _length:Int;
	var _frameGap:Int;
	var _alpha:Float;
	var _stillLimit:Float;
	var _counter:Int = 0;
	var _still:Float = 0;
	var _lastX:Float;
	var _lastY:Float;

	public function new(Sprite:FlxSprite, ?Graphic:FlxGraphicAsset, Length:Int = 5, Delay:Int = 3, Alpha:Float = 0.4, Diff:Int = 1000)
	{
		super();

		_sprite = Sprite;
		_length = Std.int(Math.max(1, Length));
		_frameGap = Std.int(Math.max(1, Delay));
		_alpha = Alpha;
		_stillLimit = Diff > 0 ? Diff / 1000 : 0;
		_lastX = Sprite.x;
		_lastY = Sprite.y;

		for (i in 0..._length)
		{
			final ghost = new FlxSprite();

			if (Graphic != null)
				ghost.loadGraphic(Graphic);
			else
				adopt(ghost, Sprite);

			ghost.alpha = ghostAlpha(i) * Sprite.alpha;
			ghost.exists = false;
			add(ghost);
		}
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (delay > 0)
		{
			delay -= elapsed;
			return;
		}

		if (finish || _sprite == null || !_sprite.exists)
			return;

		if (_sprite.x == _lastX && _sprite.y == _lastY)
			_still += elapsed;
		else
			_still = 0;
		_lastX = _sprite.x;
		_lastY = _sprite.y;

		if (_stillLimit > 0 && _still > _stillLimit)
			return;

		if (++_counter < _frameGap)
			return;
		_counter = 0;

		var i = members.length - 1;
		while (i > 0)
		{
			adopt(members[i], members[i - 1], i);
			i--;
		}

		adopt(members[0], _sprite, 0);
	}

	inline function ghostAlpha(index:Int):Float
	{
		return _alpha * (1 - index / _length);
	}

	function adopt(target:FlxSprite, source:FlxSprite, index:Int = 0):Void
	{
		target.exists = source.exists;
		target.x = source.x;
		target.y = source.y;
		target.angle = source.angle;
		target.scale.set(source.scale.x, source.scale.y);
		target.origin.set(source.origin.x, source.origin.y);
		target.offset.set(source.offset.x, source.offset.y);
		target.scrollFactor.set(source.scrollFactor.x, source.scrollFactor.y);
		target.flipX = source.flipX;
		target.flipY = source.flipY;
		target.color = source.color;

		if (target.frames != source.frames)
			target.frames = source.frames;
		target.frame = source.frame;

		target.alpha = ghostAlpha(index) * source.alpha;
	}
}
