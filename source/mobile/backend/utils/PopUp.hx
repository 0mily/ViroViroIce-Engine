package mobile.backend.utils;

import lime.app.Application;

/**
 * @Author LumiCoder
 */
class PopUp
{
	public static function showAlert(title:String, message:String, buttonLabel:String = "OK"):Void
	{
		#if android
		Interface.showAlert(title, message, buttonLabel, null);
		#else
		Application.current.window.alert(message, title);
		#end
	}

	@:overload(function(title:String, message:String, buttonData:Dynamic, ?unused:Dynamic):Void
	{
	})
	public static function showAlertLegacy(title:String, message:String, buttonData:Dynamic, ?unused:Dynamic):Void
	{
		var label = (buttonData != null && Reflect.hasField(buttonData, "name")) ? buttonData.name : "OK";
		showAlert(title, message, label);
	}

	public static function showConfirm(title:String, message:String, yesLabel:String = "Yes", noLabel:String = "No", onYes:Void->Void, ?onNo:Void->Void):Void
	{
		#if android
		Interface.showConfirm(title, message, yesLabel, noLabel, onYes, onNo);
		#else
		Application.current.window.alert(message, title);
		if (onYes != null)
			onYes();
		#end
	}
}
