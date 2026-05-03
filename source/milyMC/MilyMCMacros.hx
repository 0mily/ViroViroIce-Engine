package milyMC;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import sys.io.File;
#end

class MilyMCMacros
{
	static inline var CHUNK_SIZE:Int = 2000;

	public static macro function luaFile(pathExpr:ExprOf<String>):ExprOf<String>
	{
		var fileName:String = switch (pathExpr.expr)
		{
			case EConst(CString(value, _)): value;
			default:
				Context.error('MilyMC.luaFile expects a string literal.', pathExpr.pos);
				'';
		};

		var path:String = Context.resolvePath('milyMC/lua/$fileName.lua');
		var content:String = File.getContent(path);
		if (content.length > 0 && content.charCodeAt(0) == 0xFEFF)
			content = content.substr(1);

		var chunks:Array<Expr> = [];
		var index:Int = 0;
		while (index < content.length)
		{
			chunks.push(macro $v{content.substr(index, CHUNK_SIZE)});
			index += CHUNK_SIZE;
		}

		return macro [$a{chunks}].join('');
	}
}
