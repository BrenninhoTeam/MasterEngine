package mobile.backend;

import lime.system.System as LimeSystem;
import haxe.io.Path;
import haxe.Exception;
#if android
import lime.app.Application;
import sys.io.Process;
#end

class StorageUtil
{
	#if sys
	public static final rootDir:String = LimeSystem.applicationStorageDirectory;

	private static var _cachedPath:String = null;

	public static function getStorageDirectory(?force:Bool = false):String
	{
		if (!force && _cachedPath != null)
			return _cachedPath;

		var daPath:String = '';

		#if android
		final typeFile:String = rootDir + 'storagetype.txt';
		if (!FileSystem.exists(typeFile))
			File.saveContent(typeFile, ClientPrefs.data.storageType);

		final storageType:String = File.getContent(typeFile);
		daPath = Path.addTrailingSlash(force ? StorageType.fromStrForce(storageType) : StorageType.fromStr(storageType));
		#elseif ios
		daPath = Path.addTrailingSlash(LimeSystem.documentsDirectory);
		#else
		daPath = Sys.getCwd();
		#end

		if (!force)
			_cachedPath = daPath;

		return daPath;
	}

	public static function clearCache():Void
	{
		_cachedPath = null;
	}

	public static function initStorageDirectory():Void
	{
		final dir:String = getStorageDirectory();
		if (FileSystem.exists(dir))
			return;

		try
		{
			FileSystem.createDirectory(dir);
			trace('Storage directory initialized: $dir');
		}
		catch (e:Exception)
		{
			trace('Failed to initialize storage directory: ${e.message}');
			#if android
			CoolUtil.showPopUp('Failed to create required directory:\n' + getStorageDirectory(true) + '\nPress OK to close the game.', 'Critical Error');
			LimeSystem.exit(1);
			#end
		}
	}

	public static function saveContent(fileName:String, fileData:String, ?alert:Bool = true):Void
	{
		try
		{
			final savesDir:String = getStorageDirectory() + 'saves';
			if (!FileSystem.exists(savesDir))
				FileSystem.createDirectory(savesDir);

			File.saveContent('$savesDir/$fileName', fileData);

			if (alert)
				CoolUtil.showPopUp('$fileName saved successfully.', 'Success');
		}
		catch (e:Exception)
		{
			if (alert)
				CoolUtil.showPopUp('Failed to save $fileName.\n(${e.message})', 'Error');
			else
				trace('Failed to save $fileName: ${e.message}');
		}
	}

	public static function loadContent(fileName:String):Null<String>
	{
		final path:String = getStorageDirectory() + 'saves/$fileName';
		if (!FileSystem.exists(path))
		{
			trace('File not found: $path');
			return null;
		}
		try
		{
			return File.getContent(path);
		}
		catch (e:Exception)
		{
			trace('Failed to load $fileName: ${e.message}');
			return null;
		}
	}

	public static function fileExists(fileName:String):Bool
	{
		return FileSystem.exists(getStorageDirectory() + 'saves/$fileName');
	}

	#if android
	public static function requestPermissions():Void
	{
		final sdkInt:Int = AndroidVersion.SDK_INT;

		if (sdkInt >= AndroidVersionCode.TIRAMISU)
			AndroidPermissions.requestPermissions(['READ_MEDIA_IMAGES', 'READ_MEDIA_VIDEO', 'READ_MEDIA_AUDIO']);
		else
			AndroidPermissions.requestPermissions(['READ_EXTERNAL_STORAGE', 'WRITE_EXTERNAL_STORAGE']);

		if (!AndroidEnvironment.isExternalStorageManager())
		{
			if (sdkInt >= AndroidVersionCode.S)
				AndroidSettings.requestSetting('REQUEST_MANAGE_MEDIA');
			AndroidSettings.requestSetting('MANAGE_APP_ALL_FILES_ACCESS_PERMISSION');
		}

		final granted:Array<String> = AndroidPermissions.getGrantedPermissions();
		final hasPermission:Bool = sdkInt >= AndroidVersionCode.TIRAMISU
			? granted.contains('android.permission.READ_MEDIA_IMAGES')
			: granted.contains('android.permission.READ_EXTERNAL_STORAGE');

		if (!hasPermission)
			CoolUtil.showPopUp(
				'Storage permission was not granted.\nThe game may crash due to missing assets or mods.\nPress OK to continue.',
				'Permission Warning'
			);

		initStorageDirectory();
	}

	public static function checkExternalPaths(?splitStorage:Bool = false):Array<String>
	{
		final process:Process = new Process('grep -o "/storage/....-...." /proc/mounts | paste -sd \',\'');
		var raw:String = process.stdout.readAll().toString().trim();
		process.close();

		if (splitStorage)
			raw = raw.replace('/storage/', '');

		return raw.length > 0 ? raw.split(',') : [];
	}

	public static function getExternalDirectory(externalDir:String):String
	{
		var daPath:String = '';
		for (path in checkExternalPaths())
		{
			if (path.contains(externalDir))
			{
				daPath = path.endsWith('\n') ? path.substr(0, path.length - 1) : path;
				break;
			}
		}
		return Path.addTrailingSlash(daPath);
	}
	#end
	#end
}

#if android
@:runtimeValue
enum abstract StorageType(String) from String to String
{
	private static final forcedPath:String = '/storage/emulated/0/';
	private static final packageNameLocal:String = 'main.funkin.masterengine';
	private static final fileLocal:String = 'MasterEngine';

	var EXTERNAL_DATA = "EXTERNAL_DATA";
	var EXTERNAL_OBB = "EXTERNAL_OBB";
	var EXTERNAL_MEDIA = "EXTERNAL_MEDIA";
	var EXTERNAL = "EXTERNAL";

	public static function fromStr(str:String):StorageType
	{
		final meta = Application.current.meta;
		final pkg:String = meta.get('packageName');
		final file:String = meta.get('file');
		final extRoot:String = AndroidEnvironment.getExternalStorageDirectory();

		return switch (str)
		{
			case "EXTERNAL_DATA":  AndroidContext.getExternalFilesDir();
			case "EXTERNAL_OBB":   AndroidContext.getObbDir();
			case "EXTERNAL_MEDIA": '$extRoot/Android/media/$pkg';
			case "EXTERNAL":       '$extRoot/.$file';
			default:               StorageUtil.getExternalDirectory(str) + '.' + file;
		}
	}

	public static function fromStrForce(str:String):StorageType
	{
		return switch (str)
		{
			case "EXTERNAL_DATA":  '${forcedPath}Android/data/$packageNameLocal/files';
			case "EXTERNAL_OBB":   '${forcedPath}Android/obb/$packageNameLocal';
			case "EXTERNAL_MEDIA": '${forcedPath}Android/media/$packageNameLocal';
			case "EXTERNAL":       '$forcedPath.$fileLocal';
			default:               StorageUtil.getExternalDirectory(str) + '.' + fileLocal;
		}
	}
}
#end