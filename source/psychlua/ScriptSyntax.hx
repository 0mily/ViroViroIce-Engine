package psychlua;

using StringTools;

private typedef ScriptBlock =
{
	var indent:String;
	var close:String;
}

// (another?) conversor holy shit i'm done
class ScriptSyntax
{
	static final FLOW_BLOCK:EReg = ~/^(\s*)(from|every)\s*\((.*)\)\s*do\s*(--.*)?$/;
	static final SECTION_BLOCK:EReg = ~/^(\s*)onSection\s*\((.*)\)\s*\{\s*(--.*)?$/;
	static final STEP_BLOCK:EReg = ~/^(\s*)for\s*\{(.*)\}\s*do\s*(--.*)?$/;
	static final END_BLOCK:EReg = ~/^(\s*)end\s*(--.*)?$/;
	static final BRACE_BLOCK:EReg = ~/^(\s*)\}\s*(--.*)?$/;

	public static function process(source:String):String
	{
		if (source == null || source.length < 1)
			return source;

		var newline:String = source.indexOf('\r\n') >= 0 ? '\r\n' : '\n';
		var lines:Array<String> = source.split(newline);
		var blocks:Array<ScriptBlock> = [];
		var changed:Bool = false;

		for (index in 0...lines.length)
		{
			var line:String = lines[index];
			if (FLOW_BLOCK.match(line))
			{
				var indent:String = FLOW_BLOCK.matched(1);
				var helper:String = FLOW_BLOCK.matched(2);
				var args:String = FLOW_BLOCK.matched(3);
				var comment:String = FLOW_BLOCK.matched(4);
				lines[index] = indent + helper + '(' + args + ', function()' + suffixComment(comment);
				blocks.push({indent: indent, close: 'end'});
				changed = true;
				continue;
			}

			if (SECTION_BLOCK.match(line))
			{
				var indent:String = SECTION_BLOCK.matched(1);
				var args = splitFirstArgument(SECTION_BLOCK.matched(2));
				var comment:String = SECTION_BLOCK.matched(3);
				lines[index] = indent + 'onSection(' + args.first + ', {' + args.rest + '}, function()' + suffixComment(comment);
				blocks.push({indent: indent, close: '}'});
				changed = true;
				continue;
			}

			if (STEP_BLOCK.match(line))
			{
				var indent:String = STEP_BLOCK.matched(1);
				var steps:String = STEP_BLOCK.matched(2);
				var comment:String = STEP_BLOCK.matched(3);
				lines[index] = indent + '_scriptForSteps({' + steps + '}, function()' + suffixComment(comment);
				blocks.push({indent: indent, close: 'end'});
				changed = true;
				continue;
			}

			if (blocks.length > 0)
			{
				var block:ScriptBlock = blocks[blocks.length - 1];
				var matcher:EReg = block.close == '}' ? BRACE_BLOCK : END_BLOCK;
				if (matcher.match(line) && matcher.matched(1) == block.indent)
				{
					lines[index] = block.indent + 'end)' + suffixComment(matcher.matched(2));
					blocks.pop();
					changed = true;
				}
			}
		}

		return changed ? lines.join(newline) : source; // ive tested ts like, 2 times, the chance of this works is SO low
	}

	static function suffixComment(comment:String):String
		return comment == null || comment.length < 1 ? '' : ' ' + comment;

	static function splitFirstArgument(args:String):{first:String, rest:String}
	{
		var depth:Int = 0;
		var quote:Int = 0;
		var escaped:Bool = false;
		for (index in 0...args.length)
		{
			var code:Int = args.charCodeAt(index);
			if (quote != 0)
			{
				if (escaped)
					escaped = false;
				else if (code == '\\'.code)
					escaped = true;
				else if (code == quote)
					quote = 0;
				continue;
			}

			if (code == '"'.code || code == "'".code)
				quote = code;
			else if (code == '('.code || code == '['.code || code == '{'.code)
				depth++;
			else if (code == ')'.code || code == ']'.code || code == '}'.code)
				depth--;
			else if (code == ','.code && depth == 0)
				return {first: args.substr(0, index).trim(), rest: args.substr(index + 1).trim()};
		}
		return {first: args.trim(), rest: '0'};
	}
}
