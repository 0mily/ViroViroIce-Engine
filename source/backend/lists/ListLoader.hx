package backend.lists;

import flixel.FlxState;

#if HSCRIPT_ALLOWED
import psychlua.HScript;
#end

using StringTools;

enum abstract ListKind(String) from String to String
{
	var CHARACTER = 'Character';
	var EVENT = 'Event';
	var STAGE = 'Stage';
	var LEVEL = 'Level';
}

typedef ListCategoryData =
{
	var category:String;
	var names:Array<String>;
	var source:String;
	var modded:Bool;
}

class ListLoader
{
	public static inline final LIST_DIRECTORY:String = 'data/lists/';
	static final SCRIPT_EXTENSIONS:Array<String> = ['.hx', '.hxc', '.hscript'];

	public static function load(kind:ListKind, ?parent:FlxState):Array<ListCategoryData>
	{
		var output:Array<ListCategoryData> = [];

		#if (HSCRIPT_ALLOWED && sys)
		var directories:Array<String> = Mods.directoriesWithFile(Paths.getSharedPath(), LIST_DIRECTORY);
		for(directory in directories)
		{
			var files:Array<String> = FileSystem.readDirectory(directory);
			files.sort(Reflect.compare);

			for(file in files)
			{
				if(file == null || file.toLowerCase().startsWith('readme.'))
					continue;

				var extension:String = haxe.io.Path.extension(file);
				if(extension == null || !SCRIPT_EXTENSIONS.contains('.' + extension.toLowerCase()))
					continue;

				var path:String = haxe.io.Path.join([directory, file]);
				if(FileSystem.isDirectory(path))
					continue;

				var code:String = null;
				try code = File.getContent(path) catch(e:Dynamic) {
					trace('[ListLoader] Could not read "$path": $e');
				}
				if(code == null)
					continue;

				var prepared:PreparedListScript = prepareScript(code, kind, path);
				if(prepared == null)
					continue;

				var rawCategories:Dynamic = runScript(prepared.code, path, parent);
				appendCategories(output, rawCategories, path, !path.replace('\\', '/').startsWith(Paths.getSharedPath().replace('\\', '/')));
			}
		}
		#end

		return output;
	}

	public static function names(categories:Array<ListCategoryData>):Array<String>
	{
		var output:Array<String> = [];
		if(categories == null)
			return output;

		for(group in categories)
			if(group != null && group.names != null)
				for(name in group.names)
					if(name != null && name.length > 0 && !output.contains(name))
						output.push(name);
		return output;
	}

	public static function appendNames(target:Array<String>, categories:Array<ListCategoryData>):Array<String>
	{
		if(target == null)
			target = [];
		for(name in names(categories))
			if(!target.contains(name))
				target.push(name);
		return target;
	}

	public static function categorize(categories:Array<ListCategoryData>, available:Array<String>, ?includeEmpty:Bool = false):Array<ListCategoryData>
	{
		var result:Array<ListCategoryData> = [];
		var claimed:Array<String> = [];
		var uncategorized:Array<String> = [];
		var allowed:Array<String> = [];

		if(available != null)
			for(value in available)
			{
				if(value == null)
					continue;
				var normalized:String = value.trim();
				if((normalized.length > 0 || includeEmpty) && !allowed.contains(normalized))
					allowed.push(normalized);
			}

		if(categories != null)
			for(group in categories)
			{
				if(group == null || group.names == null)
					continue;

				var filtered:Array<String> = [];
				for(name in group.names)
				{
					if(name == null)
						continue;
					name = name.trim();
					if(!allowed.contains(name) || claimed.contains(name))
						continue;
					claimed.push(name);
					if(group.category.toLowerCase() == 'uncategorized')
						uncategorized.push(name);
					else
						filtered.push(name);
				}

				if(filtered.length > 0)
					result.push({
						category: group.category,
						names: filtered,
						source: group.source,
						modded: group.modded
					});
			}

		for(name in allowed)
			if(!claimed.contains(name) && !uncategorized.contains(name))
				uncategorized.push(name);

		if(uncategorized.length > 0)
			result.push({category: 'Uncategorized', names: uncategorized, source: '', modded: false});
		return result;
	}

	#if HSCRIPT_ALLOWED
	static function runScript(code:String, path:String, parent:FlxState):Dynamic
	{
		var script:HScript = null;
		var result:Dynamic = null;
		try
		{
			script = new HScript(null, code, null, true, parent);
			script.filePath = path;
			script.origin = path;
			#if ADDONS_ALLOWED
			script.modFolder = Mods.getModFolderFromPath(path);
			#end
			script.unsafe = true;
			script.execute();
			script.unsafe = false;

			if(!script.exists('getCategories'))
			{
				trace('[ListLoader] "$path" does not define getCategories().');
			}
			else
			{
				var call = script.call('getCategories');
				result = call != null ? call.returnValue : null;
			}
		}
		catch(e:Dynamic)
		{
			trace('[ListLoader] Failed to execute "$path": $e');
		}

		if(script != null)
			script.destroy();
		return result;
	}
	#end

	static function appendCategories(output:Array<ListCategoryData>, raw:Dynamic, path:String, modded:Bool):Void
	{
		if(raw == null || !Std.isOfType(raw, Array))
		{
			trace('[ListLoader] getCategories() in "$path" must return an Array.');
			return;
		}

		var rawArray:Array<Dynamic> = cast raw;
		for(entry in rawArray)
		{
			if(entry == null)
				continue;

			var categoryValue:Dynamic = Reflect.field(entry, 'category');
			var namesValue:Dynamic = Reflect.field(entry, 'names');
			if(categoryValue == null || !Std.isOfType(namesValue, Array))
			{
				trace('[ListLoader] Ignored an invalid category in "$path" (expected category + names).');
				continue;
			}

			var category:String = Std.string(categoryValue).trim();
			if(category.length < 1)
				category = 'Uncategorized';

			var categoryNames:Array<String> = [];
			for(value in (cast namesValue:Array<Dynamic>))
			{
				if(value == null)
					continue;
				var name:String = Std.string(value).trim();
				if(name.length > 0 && !categoryNames.contains(name))
					categoryNames.push(name);
			}

			if(categoryNames.length > 0)
				output.push({category: category, names: categoryNames, source: path, modded: modded});
		}
	}

	static function prepareScript(code:String, kind:ListKind, path:String):PreparedListScript
	{
		var declaration:EReg = ~/class\s+([A-Za-z_][A-Za-z0-9_]*)\s+extends\s+([A-Za-z_][A-Za-z0-9_\.]*)/m;
		if(!declaration.match(code))
		{
			trace('[ListLoader] Ignored "$path": list scripts must declare a class with extends ${kind}.');
			return null;
		}

		var parentName:String = declaration.matched(2);
		var shortParent:String = parentName.indexOf('.') >= 0 ? parentName.substr(parentName.lastIndexOf('.') + 1) : parentName;
		if(shortParent != Std.string(kind))
			return null;

		var requiredImport:String = 'backend.lists.${kind}';
		if(parentName.indexOf('.') < 0)
		{
			var importExpression:EReg = new EReg('import\\s+' + requiredImport.replace('.', '\\.') + '\\s*;', 'm');
			if(!importExpression.match(code))
			{
				trace('[ListLoader] Ignored "$path": extends ${kind} requires import $requiredImport;.');
				return null;
			}
		}
		else if(parentName != requiredImport)
			return null;

		var declarationPosition = declaration.matchedPos();
		var openBrace:Int = findClassOpenBrace(code, declarationPosition.pos + declarationPosition.len);
		if(openBrace < 0)
		{
			trace('[ListLoader] Ignored "$path": expected the list class body after extends ${kind}.');
			return null;
		}
		var closeBrace:Int = matchingBrace(code, openBrace);
		if(closeBrace < 0)
		{
			trace('[ListLoader] Ignored "$path": the list class has no closing brace.');
			return null;
		}

		var preamble:String = code.substr(0, declarationPosition.pos);
		var body:String = code.substring(openBrace + 1, closeBrace);
		for(access in ['public', 'private', 'override', 'static', 'inline', 'extern'])
		{
			body = new EReg('\\b' + access + '\\s+', 'g').replace(body, '');
		}
		body = removeConstructor(body);

		return {code: preamble + '\n' + body};
	}

	static function findClassOpenBrace(code:String, start:Int):Int
	{
		var i:Int = start;
		while(i < code.length)
		{
			var current:Int = code.charCodeAt(i);
			var next:Int = i + 1 < code.length ? code.charCodeAt(i + 1) : -1;
			if(current == 32 || current == 9 || current == 10 || current == 13)
			{
				i++;
				continue;
			}
			if(current == 47 && next == 47)
			{
				i += 2;
				while(i < code.length && code.charCodeAt(i) != 10 && code.charCodeAt(i) != 13)
					i++;
				continue;
			}
			if(current == 47 && next == 42)
			{
				var end:Int = code.indexOf('*/', i + 2);
				if(end < 0)
					return -1;
				i = end + 2;
				continue;
			}
			return current == 123 ? i : -1;
		}
		return -1;
	}

	static function removeConstructor(body:String):String
	{
		var constructor:EReg = ~/function\s+new\s*\(/m;
		if(!constructor.match(body))
			return body;

		var position = constructor.matchedPos();
		var openBrace:Int = body.indexOf('{', position.pos + position.len);
		if(openBrace < 0)
			return body;
		var closeBrace:Int = matchingBrace(body, openBrace);
		if(closeBrace < 0)
			return body;

		return body.substr(0, position.pos) + body.substr(closeBrace + 1);
	}

	static function matchingBrace(code:String, openBrace:Int):Int
	{
		var depth:Int = 0;
		var quote:Int = 0;
		var escaped:Bool = false;
		var lineComment:Bool = false;
		var blockComment:Bool = false;
		var i:Int = openBrace;

		while(i < code.length)
		{
			var current:Int = code.charCodeAt(i);
			var next:Int = i + 1 < code.length ? code.charCodeAt(i + 1) : -1;

			if(lineComment)
			{
				if(current == 10 || current == 13)
					lineComment = false;
				i++;
				continue;
			}
			if(blockComment)
			{
				if(current == 42 && next == 47)
				{
					blockComment = false;
					i += 2;
					continue;
				}
				i++;
				continue;
			}
			if(quote != 0)
			{
				if(escaped)
					escaped = false;
				else if(current == 92)
					escaped = true;
				else if(current == quote)
					quote = 0;
				i++;
				continue;
			}

			if(current == 47 && next == 47)
			{
				lineComment = true;
				i += 2;
				continue;
			}
			if(current == 47 && next == 42)
			{
				blockComment = true;
				i += 2;
				continue;
			}
			if(current == 34 || current == 39)
			{
				quote = current;
				i++;
				continue;
			}
			if(current == 123)
				depth++;
			else if(current == 125)
			{
				depth--;
				if(depth == 0)
					return i;
			}
			i++;
		}
		return -1;
	}
}

private typedef PreparedListScript =
{
	var code:String;
}
