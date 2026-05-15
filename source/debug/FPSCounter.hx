package debug;

import flixel.FlxG;
import openfl.text.TextField;
import openfl.text.TextFormat;
import lime.system.System as LimeSystem;

#if cpp
#if windows
@:cppFileCode('#include <windows.h>')
#elseif (ios || mac)
@:cppFileCode('#include <mach-o/arch.h>')
#else
@:headerInclude('sys/utsname.h')
#end
#end
class FPSCounter extends TextField
{
	public var currentFPS(default, null):Int = 0;

	private static inline final ENGINE_NAME:String = 'Master Engine';
	private static inline final ENGINE_VERSION:String = '0.1.0';
	private static inline final SAMPLE_WINDOW_MS:Float = 1000.0;
	private static inline final UPDATE_INTERVAL_MS:Float = 50.0;

	@:noCompletion private var times:Array<Float> = [];
	@:noCompletion private var deltaAccum:Float = 0.0;

	public function new(x:Float = 10, y:Float = 10, color:Int = 0xFFFFFF)
	{
		super();

		selectable   = false;
		mouseEnabled = false;
		multiline    = true;
		defaultTextFormat = new TextFormat('_sans', 14, color);
		width = FlxG.width;
		text  = '';

		positionFPS(x, y);
	}

	private override function __enterFrame(deltaTime:Float):Void
	{
		deltaAccum += deltaTime;
		if (deltaAccum < UPDATE_INTERVAL_MS)
			return;
		deltaAccum = 0.0;

		final now:Float = haxe.Timer.stamp() * 1000.0;
		times.push(now);
		while (times.length > 0 && times[0] < now - SAMPLE_WINDOW_MS)
			times.shift();

		currentFPS = Std.int(Math.min(times.length, FlxG.updateFramerate));
		updateText();
	}

	public dynamic function updateText():Void
	{
		final fpsPct:Float = currentFPS / FlxG.drawFramerate;

		textColor = switch true
		{
			case _ if (fpsPct >= 0.85): 0xFFFFFFFF;
			case _ if (fpsPct >= 0.5):  0xFFFFAA00;
			default:                    0xFFFF4444;
		}

		text = 'FPS: $currentFPS'
			+ '\n$ENGINE_NAME $ENGINE_VERSION';
	}

	public inline function positionFPS(X:Float, Y:Float, ?scale:Float = 1):Void
	{
		scaleX = scaleY = #if android (scale > 1 ? scale : 1) #else (scale < 1 ? scale : 1) #end;
		x = FlxG.game.x + X;
		y = FlxG.game.y + Y;
	}

	#if cpp
	@:noCompletion
	#if windows
	@:functionCode('
		SYSTEM_INFO info;
		GetSystemInfo(&info);
		switch (info.wProcessorArchitecture)
		{
			case 9:  return ::String("x86_64");
			case 5:  return ::String("ARM");
			case 12: return ::String("ARM64");
			case 6:  return ::String("IA-64");
			case 0:  return ::String("x86");
			default: return ::String("Unknown");
		}
	')
	#elseif (ios || mac)
	@:functionCode('
		const NXArchInfo *info = NXGetLocalArchInfo();
		return ::String(info == NULL ? "Unknown" : info->name);
	')
	#else
	@:functionCode('
		struct utsname info{};
		uname(&info);
		return ::String(info.machine);
	')
	#end
	private function getArch():String
		return 'Unknown';
	#end
}