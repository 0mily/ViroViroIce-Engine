package options;

class ViroViroOptionsSubState extends BaseOptionsMenu
{
    public function new() {
        super(Language.getPhrase('vvie_menu', 'Engine Settings'), 'Engine Settings Menu');
		

		var option:Option = new Option('Mechanics',
			'Enables mechanics.',
			'mechanics',
			BOOL);
		addOption(option);

        var option:Option = new Option('Modchart',
			'Enables modchart.',
			'modchart',
			BOOL);
		addOption(option);

		var option:Option = new Option('Week 6 Pixel Rendering',
			'Enables that one removed week 6 pixel perfect rendering.',
			'weekpixel',
			BOOL);
		addOption(option);

		var option:Option = new Option('no Miku D-sides',
			'Disables the cool Miku easter egg when pressing "M". :(',
			'mikudside',
			BOOL);
		addOption(option);

		var option:Option = new Option('Screenshots',
			'If checked, the screenshot hotkey will save a PNG in the screenshots folder.',
			'screenshots',
			BOOL);
		addOption(option);

		var option:Option = new Option('Screenshot Key',
			'Press this key to save a screenshot. PrtScr also works tho.',
			'screenshotKey',
			KEYBIND);
		addOption(option);

		/*var option:Option = new Option('Custom Score',
			'Disables the default score text and enables the custom one, which can be edited with a Script.lua.',
			'customScore',
			BOOL);
		addOption(option);*/

        var option:Option = new Option('Extra',
			'Eles estao de olho em nois da silva.',
			'extra',
			BOOL);
		addOption(option);

    }
}
