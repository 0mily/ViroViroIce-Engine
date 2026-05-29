package mobile.states;

import lime.utils.Assets as LimeAssets;
import openfl.utils.Assets as OpenFLAssets;
import flixel.addons.util.FlxAsyncLoop;
import openfl.utils.ByteArray;
import haxe.io.Path;
import flixel.ui.FlxBar;
import flixel.ui.FlxBar.FlxBarFillDirection;

import states.InitState;
import backend.MusicBeatState;

import haxe.crypto.Md5;

// I won't delete this
/**
 * ...
 * @author: Karim Akra
 */
class CopyState extends MusicBeatState
{
	private static final textFilesExtensions:Array<String> = ['lua'];
	public static final IGNORE_FOLDER_FILE_NAME:String = "ignore.txt";
	private static var directoriesToIgnore:Array<String> = ['assets'];
	public static var locatedFiles:Array<String> = [];
	public static var maxLoopTimes:Int = 0;

	public var loadingImage:FlxSprite;
	public var loadingBar:FlxBar;
	public var loadedText:FlxText;
	public var copyLoop:FlxAsyncLoop;

	var failedFilesStack:Array<String> = [];
	var failedFiles:Array<String> = [];
	var shouldCopy:Bool = false;
	var canUpdate:Bool = true;
	var loopTimes:Int = 0;

	override function create()
	{
		locatedFiles = [];
		maxLoopTimes = 0;
		checkExistingFiles();
		if (maxLoopTimes <= 0)
		{
			MusicBeatState.switchState(new InitState());
			return;
		}

		CoolUtil.showPopUp(Language.getPhrase('mobile_missing_files', "Seems like you have some missing files that are necessary to run the game\nPress OK to begin the copy process"), Language.getPhrase('mobile_notice', "Notice!"));

		shouldCopy = true;

		add(new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, 0xffcaff4d));

		loadingImage = new FlxSprite(0, 0, Paths.image('funkay'));
		loadingImage.setGraphicSize(0, FlxG.height);
		loadingImage.updateHitbox();
		loadingImage.screenCenter();
		add(loadingImage);

		loadingBar = new FlxBar(0, FlxG.height - 26, FlxBarFillDirection.LEFT_TO_RIGHT, FlxG.width, 26);
		loadingBar.setRange(0, maxLoopTimes);
		add(loadingBar);

		loadedText = new FlxText(loadingBar.x, loadingBar.y + 4, FlxG.width, '', 16);
		loadedText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER);
		add(loadedText);

		var ticks:Int = 15;
		if (maxLoopTimes <= 15)
			ticks = 1;

		copyLoop = new FlxAsyncLoop(maxLoopTimes, copyAsset, ticks);
		add(copyLoop);
		copyLoop.start();

		super.create();
	}

	override function update(elapsed:Float)
	{
		if (shouldCopy && copyLoop != null)
		{
			loadingBar.percent = loopTimes / maxLoopTimes * 100;
			if (copyLoop.finished && canUpdate)
			{
				if (failedFiles.length > 0)
				{
					CoolUtil.showPopUp(failedFiles.join('\n'), 'Failed To Copy ${failedFiles.length} File.');
					if (!FileSystem.exists('logs'))
						FileSystem.createDirectory('logs');
					File.saveContent('logs/' + Date.now().toString().replace(' ', '-').replace(':', "'") + '-CopyState' + '.txt', failedFilesStack.join('\n'));
				}
				canUpdate = false;
				FlxG.sound.play(Paths.sound('confirmMenu')).onComplete = () ->
				{
					MusicBeatState.switchState(new InitState());
				};
			}

			if (loopTimes == maxLoopTimes)
				loadedText.text = "Completed!";
			else
				loadedText.text = '$loopTimes/$maxLoopTimes';
		}
		super.update(elapsed);
	}

	public function copyAsset()
	{
    	var file = locatedFiles[loopTimes];
    	var assetPath = getFile(file);
    	loopTimes++;
    
    	var directory = Path.directory(file);
    	if (!FileSystem.exists(directory))
        	StorageUtil.createDirectories(directory);
    	try
    	{
        	if (OpenFLAssets.exists(assetPath))
        	{
            	var bytes = getFileBytes(assetPath);
            	File.saveBytes(file, bytes); 
            	if (textFilesExtensions.contains(Path.extension(file)))
                	createContentFromInternal(file);
        	}
    	}
	}

	public function createContentFromInternal(file:String)
	{
		var fileName = Path.withoutDirectory(file);
		var directory = Path.directory(file);
		try
		{
			var fileData:String = OpenFLAssets.getText(getFile(file));
			if (fileData == null)
				fileData = '';
			if (!FileSystem.exists(directory))
				StorageUtil.createDirectories(directory);
			File.saveContent(Path.join([directory, fileName]), fileData);
		}
		catch (e:haxe.Exception)
		{
			failedFiles.push('${getFile(file)} (${e.message})');
			failedFilesStack.push('${getFile(file)} (${e.stack})');
		}
	}

	public function getFileBytes(file:String):ByteArray
	{
		switch (Path.extension(file).toLowerCase())
		{
			case 'otf' | 'ttf':
				return ByteArray.fromFile(file);
			default:
				return OpenFLAssets.getBytes(file);
		}
	}

	public static function getFile(file:String):String
	{
		if (OpenFLAssets.exists(file))
			return file;

		@:privateAccess
		for (library in LimeAssets.libraries.keys())
		{
			if (OpenFLAssets.exists('$library:$file') && library != 'default')
				return '$library:$file';
		}

		return file;
	}

	public static function checkExistingFiles():Bool
	{
    	locatedFiles = OpenFLAssets.list();
    
    	var mods = locatedFiles.filter(folder -> folder.startsWith('mods/'));
    	locatedFiles = mods; 
    	locatedFiles = locatedFiles.filter(file -> {
        	if (!FileSystem.exists(file)) return true;
        
        	if (textFilesExtensions.contains(Path.extension(file))) {
            	var apkBytes = OpenFLAssets.getBytes(getFile(file));
            	var externalBytes = File.getBytes(file);
            
            	return Md5.make(apkBytes).toHex() != Md5.make(externalBytes).toHex();
        	}
        
        	return false;
    	});
    
    	var filesToRemove:Array<String> = [];

    	maxLoopTimes = locatedFiles.length;
    	return (maxLoopTimes <= 0);
	}
}