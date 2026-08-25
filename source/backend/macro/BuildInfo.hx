package backend.macro;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import sys.io.Process;
#end

class BuildInfo
{
	public static macro function getCommit():ExprOf<String>
	{
		#if display 
		return macro $v{'unknown'};
		#else
		var commit:String = normalizeCommit(Context.definedValue('BUILD_COMMIT'));
		if (commit == null)
			commit = normalizeCommit(Sys.getEnv('GITHUB_SHA'));

		var readFromGit:Bool = commit == null;
		if (readFromGit)
			commit = normalizeCommit(runGit(['rev-parse', 'HEAD']));

		if (commit == null)
			commit = 'unknown';
		else if (readFromGit)
		{
			var status:String = runGit(['status', '--porcelain']);
			if (status != null && status.length > 0)
				commit += '-dirty';
		}

		return macro $v{commit};
		#end
	}

	#if macro
	static function normalizeCommit(value:Null<String>):Null<String>
	{
		if (value == null)
			return null;

		value = StringTools.trim(value);
		if (!~/^[0-9a-fA-F]{7,}$/.match(value))
			return null;

		return value.substr(0, 7).toLowerCase();
	}

	static function runGit(arguments:Array<String>):Null<String>
	{
		var process:Process = null;
		try
		{
			process = new Process('git', arguments);
			var output:String = StringTools.trim(process.stdout.readAll().toString());
			var exitCode:Int = process.exitCode();
			process.close();

			return exitCode == 0 ? output : null;
		}
		catch (error:Dynamic)
		{
			if (process != null)
			{
				try process.close()
				catch (closeError:Dynamic) {}
			}
			return null;
		}
	}
	#end
}
