package mobile.backend;

import lime.app.Application;

import haxe.io.Path;
import haxe.io.Bytes;

import openfl.utils.ByteArray;
import openfl.utils.Assets;

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

/** * @Authors StarNova (Cream.BR), LumiCoder (FNF BR)
 * @version 0.1.8
 */
class StorageSystem
{
	private static var folderName(get, never):String;
	
	private static function get_folderName():String
	{
		return Application.current.meta.get('file');
	}
	
	private static var packageName(get, never):String;
	
	private static function get_packageName():String
	{
		return Application.current.meta.get('packageName');
	}
	
	/**
	 * Returns the base storage directory path.
	 */
	public static function getDirectory():String
	{
		#if android
		return Environment.getExternalStorageDirectory() + '/.' + folderName + '/';
		#elseif ios
		return lime.system.System.documentsDirectory;
		#else
		return Sys.getCwd();
		#end
	}
	
	/**
	 * Returns the assets directory path.
	 */
	public static function getAssetsDirectory():String
	{
		#if android
		return Environment.getExternalStorageDirectory() + '/Android/media/' + packageName + '/';
		#elseif ios
		return lime.system.System.documentsDirectory;
		#else
		return Sys.getCwd();
		#end
	}
	
	/**
	 * Requests Android storage permissions and verifies external assets.
	 * @return Bool Returns TRUE if the game boot should halt (permissions pending or full extract), FALSE if ready to play.
	 */
	public static function getPermissions():Bool
	{
		#if android
		if (VERSION.SDK_INT >= VERSION_CODES.TIRAMISU)
		{
			PermissionUtils.requestPermissions([
				'READ_MEDIA_IMAGES',
				'READ_MEDIA_VIDEO',
				'READ_MEDIA_AUDIO',
				'READ_MEDIA_VISUAL_USER_SELECTED'
			]);
		}
		else
		{
			PermissionUtils.requestPermissions(['READ_EXTERNAL_STORAGE', 'WRITE_EXTERNAL_STORAGE']);
		}
		
		if (VERSION.SDK_INT >= VERSION_CODES.R)
		{
			if (!Environment.isExternalStorageManager()) 
			{
				Interface.requestSetting('MANAGE_APP_ALL_FILES_ACCESS_PERMISSION');
				return true;
			}
		}
		
		try
		{
			var paths = [getAssetsDirectory(), getDirectory()];
			if (!FileSystem.exists(paths[0])) FileSystem.createDirectory(paths[0]);
			if (!FileSystem.exists(paths[1])) FileSystem.createDirectory(paths[1]);
			
			// Creating .nomedia files to avoid images remaining in the gallery
			if (!FileSystem.exists(paths[0] + ".nomedia")) File.saveContent(paths[0] + ".nomedia", "/storage/emulated/0/Android/media/" + packageName);
			
			if (!FileSystem.exists(paths[0] + "assets") || !FileSystem.exists(paths[1] + "mods"))
			{
				startApkCopy();
				return true;
			}
			else
			{
				trace("Running silent integrity check...");
				var restoredAssets = copyFromAPK("assets/", null, false, getAssetsDirectory());
				var restoredContent = copyFromAPK("mods/", null, false);
				
				if (restoredAssets > 0 || restoredContent > 0)
				{
					trace('Integrity Check fixed missing files! Restored: ${restoredAssets + restoredContent} files.');
				}
				
				return false;
			}
		}
		catch (e:Dynamic)
		{
			trace("Storage Error: " + e);
		}
		#end
		
		return false; // If not Android, or no interruption needed, proceed.
	}
	
	/**
	 * Initiates the internal APK asset extraction with UI alerts (Full Installation).
	 */
	private static function startApkCopy():Void
	{
		#if android
		PopUp.showAlert("Extracting Files", "Extracting assets from APK. Please wait.", "OK");
		
		try
		{
			copyFromAPK("assets/", null, true, getAssetsDirectory());
			copyFromAPK("mods/", null, true);
			
			PopUp.showConfirm("Success!", "Files extracted. The game will now restart.", "Restart", "Cancel", function() {
				lime.system.System.exit(0);
			});
		}
		catch (e:Dynamic)
		{
			trace("Error during Full Extraction: " + e);
		}
		#end
	}
	
	/**
	 * Recursively copies folders from the APK to external directory.
	 * @return Int The number of files successfully copied.
	 */
	public static function copyFromAPK(sourceDir:String, ?targetDir:String = null, ?forceOverwrite:Bool = true, ?baseDirectory:String):Int
	{
		var copiedCount = 0;
		
		#if mobile
		if (!StringTools.endsWith(sourceDir, "/")) sourceDir += "/";
		
		if (baseDirectory == null) baseDirectory = getDirectory();
		if (targetDir == null) targetDir = baseDirectory + sourceDir;
		if (!StringTools.endsWith(targetDir, "/")) targetDir += "/";
		
		try
		{
			if (!FileSystem.exists(targetDir)) createDirectoryRecursive(targetDir);
			
			var assetList:Array<String> = Assets.list();
			
			for (assetPath in assetList)
			{
				if (StringTools.startsWith(assetPath, sourceDir))
				{
					var relativePath = assetPath.substring(sourceDir.length);
					if (relativePath == "" || relativePath == null) continue;
					
					if (StringTools.startsWith(relativePath, "embeds/")) relativePath = relativePath.substring(7);
					else if (StringTools.startsWith(relativePath, "game/")) relativePath = relativePath.substring(5);
					
					var fullTargetPath = targetDir + relativePath;
					var targetFolder = Path.directory(fullTargetPath);
					
					if (!FileSystem.exists(targetFolder)) createDirectoryRecursive(targetFolder);
					
					if (Assets.exists(assetPath))
					{
						if (FileSystem.exists(fullTargetPath) && !forceOverwrite) continue;
						
						var fileBytes:Bytes = null;
						try { fileBytes = Assets.getBytes(assetPath); } catch (e:Dynamic) {}
						
						if (fileBytes != null)
						{
							File.saveBytes(fullTargetPath, fileBytes);
							copiedCount++;
						}
						else
						{
							try
							{
								var b:ByteArray = Assets.getBytes(assetPath);
								if (b != null)
								{
									File.saveBytes(fullTargetPath, Bytes.ofData(b));
									copiedCount++;
								}
								else if (!StringTools.endsWith(assetPath, ".ttf") && !StringTools.endsWith(assetPath, ".otf"))
								{
									var text = Assets.getText(assetPath);
									if (text != null)
									{
										File.saveContent(fullTargetPath, text);
										copiedCount++;
									}
								}
							}
							catch (e:Dynamic)
							{
								if (!FileSystem.exists(fullTargetPath)) trace('Warn: failure extracting $assetPath');
							}
						}
					}
				}
			}
			
			if (copiedCount > 0) trace('Extraction Success! $copiedCount files written to: $targetDir');
		}
		catch (e:Dynamic)
		{
			trace('Critical Error during copyFromAPK: $e');
		}
		#end
		
		return copiedCount;
	}
	
	/**
	 * Saves text content to the internal 'files' directory.
	 */
	#if sys
	public static function saveContent(name:String = 'file', ext:String = '.json', data:String = ''):Void
	{
		var saveFolder:String = Path.join([getDirectory(), "files"]);
		var fullPath:String = Path.join([saveFolder, name + ext]);
		
		try
		{
			if (!FileSystem.exists(saveFolder)) FileSystem.createDirectory(saveFolder);
			
			File.saveContent(fullPath, data);
			PopUp.showAlert("Success!", "File saved in:\n" + saveFolder + "/" + name + ext, "OK");
		}
		catch (e:haxe.Exception)
		{
			var errorMsg:String = "Error on Save!:\n" + e.message;
			trace('Error ' + errorMsg);
			PopUp.showAlert("Error saving file", errorMsg, "Close");
		}
	}
	#end
	
	/**
	 * Creates folders recursively in a safe way, fixing absolute path issues.
	 */
	private static function createDirectoryRecursive(path:String):Void
	{
		#if mobile
		if (FileSystem.exists(path)) return;
		
		var pathParts = path.split("/");
		var currentPath = "";
		
		if (StringTools.startsWith(path, "/"))
		{
			currentPath = "/";
			pathParts.shift();
		}
		
		for (part in pathParts)
		{
			if (part == "") continue;
			
			currentPath = (currentPath == "/") ? (currentPath + part) : (currentPath + "/" + part);
			
			if (!FileSystem.exists(currentPath))
			{
				try
				{
					FileSystem.createDirectory(currentPath);
				}
				catch (e:Dynamic)
				{
					trace('Error Creating Subfolder $currentPath: $e');
				}
			}
		}
		#end
	}
}