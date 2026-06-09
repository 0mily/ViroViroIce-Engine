package backend;

import haxe.Json;

// and here we go again

// i should used https://github.com/hamaluik/haxe-toml but it never works so i gave up real fast

using StringTools;

typedef TableThing = {
	var name:String;
	var data:Dynamic;
	var order:Int;
}

typedef DocThing = {
	var root:Dynamic;
	var tables:Array<TableThing>;
}

class Toml
{
	public static function parse(input:String, ?sourceName:String):DocThing
	{
		var root:Dynamic = {};
		var tables:Array<TableThing> = [];
		var current:Dynamic = root;
		var lines:Array<String> = input.replace('\r\n', '\n').replace('\r', '\n').split('\n'); // idk if there is a better way to fuck with that
		var i:Int = 0;
		while(i < lines.length)
		{
			var line:String = shitComment(lines[i]).trim();
			i++;
			if(line.length < 1)
				continue;

			if(line.startsWith('[') && line.endsWith(']') && !line.startsWith('[['))
			{
				var tableName:String = line.substr(1, line.length - 2).trim();
				current = {};
				tables.push({name: tableName, data: current, order: tables.length + 1});
				continue;
			}

			var eq:Int = findEquals(line);
			if(eq < 0)
				throw 'Invalid TOML assignment in ${sourceName ?? "document"}: $line';

			var key:String = parseKey(line.substr(0, eq).trim());
			var value:String = line.substr(eq + 1).trim();
			while(!valueIsComplete(value) && i < lines.length)
			{
				var next:String = shitComment(lines[i]).trim();
				value += '\n' + next;
				i++;
			}
			Reflect.setField(current, key, parseValue(value));
		}

		return {root: root, tables: tables};
	}

	static function findEquals(line:String):Int
	{
		var quote:String = null;
		var escaped:Bool = false;
		for(i in 0...line.length)
		{
			var c:String = line.charAt(i);
			if(quote != null)
			{
				if(quote == '"' && escaped)
				{
					escaped = false;
					continue;
				}
				if(quote == '"' && c == '\\')
					escaped = true;
				else if(c == quote)
					quote = null;
			}
			else
			{
				if(c == '"' || c == "'")
					quote = c;
				else if(c == '=')
					return i;
			}
		}
		return -1;
	}

	static function shitComment(line:String):String // aint i funny people?
	{
		var quote:String =  null;
		var escaped:Bool = false;
		for(i in 0...line.length)
		{
			var c:String = line.charAt(i);
			if(quote != null)
			{
				if(quote == '"' && escaped)
				{
					escaped = false;
					continue;
				}
				if(quote == '"' && c == '\\')
					escaped = true;
				else if(c == quote)
					quote = null;
			}
			else
			{
				if(c == '"' || c == "'")
					quote = c;
				else if(c == '#')
					return line.substr(0, i);
			}
		}
		return line;
	}

	static function valueIsComplete(value:String):Bool
	{
		var quote:String = null;
		var escaped:Bool = false;
		var depth:Int = 0;
		for(i in 0...value.length)
		{
			var c:String = value.charAt(i);
			if(quote != null)
			{
				if(quote == '"' && escaped)
				{
					escaped = false;
					continue;
				}
				if(quote == '"' && c == '\\')
					escaped = true;
				else if(c == quote)
					quote = null;
			}
			else
			{
				if(c == '"' || c == "'")
					quote = c;
				else if(c == '[')
					depth++;
				else if(c == ']')
					depth--;
			}
		}
		return quote == null && depth <= 0;
	}

	static function parseKey(key:String):String
	{
		if((key.startsWith('"') && key.endsWith('"')) || (key.startsWith("'") && key.endsWith("'")))
			return Std.string(parseValue(key));
		return key;
	}

	static function parseValue(value:String):Dynamic
	{
		value = value.trim();
		if(value.length < 1)
			return '';

		if(value.startsWith("'") && value.endsWith("'"))
			return value.substr(1, value.length - 2);

		if(value.startsWith('"') && value.endsWith('"'))
		{
			try
				return Json.parse(value)
			catch(e:Dynamic)
				return value.substr(1, value.length - 2);
		}

		if(value.startsWith('[') && value.endsWith(']'))
			return parseArray(value.substr(1, value.length - 2));

		var lower:String = value.toLowerCase();
		if(lower == 'true')
			return true;
		if(lower == 'false')
			return false;

		var asInt:Null<Int> = Std.parseInt(value);
		var asFloat:Float = Std.parseFloat(value);
		if(!Math.isNaN(asFloat) && Std.string(asFloat) == Std.string(asInt))
			return asInt;
		if(!Math.isNaN(asFloat))
			return asFloat;

		return value;
	}

	static function parseArray(value:String):Array<Dynamic>
	{
		var result:Array<Dynamic> = [];
		value = value.trim();
		if(value.length < 1)
			return result;

		for(part in splitTopLevel(value, ','))
		{
			part = part.trim();
			if(part.length > 0)
				result.push(parseValue(part));
		}
		return result;
	}

	static function splitTopLevel(value:String, delimiter:String):Array<String>
	{
		var result:Array<String> = [];
		var quote:String = null;
		var escaped:Bool = false;
		var depth:Int = 0;
		var start:Int = 0;
		for(i in 0...value.length)
		{
			var c:String = value.charAt(i);
			if(quote != null)
			{
				if(quote == '"' && escaped)
				{
					escaped = false;
					continue;
				}
				if(quote == '"' && c == '\\')
					escaped = true;
				else if(c == quote)
					quote = null;
			}
			else
			{
				if(c == '"' || c == "'")
					quote = c;
				else if(c == '[')
					depth++;
				else if(c == ']')
					depth--;
				else if(c == delimiter && depth == 0)
				{
					result.push(value.substr(start, i - start));
					start = i + 1;
				}
			}
		}
		result.push(value.substr(start));
		return result;
	}
}
