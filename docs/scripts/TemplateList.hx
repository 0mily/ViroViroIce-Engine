import backend.lists.*;

// * can be: Event - Character - Stage - Level

class MyList extends *
{
	public function new()
	{
		super();
	}

	public function getCategories():Array<Dynamic>
	{
		return [cameraEvents(), customEvents()];
	}

	public function cameraEvents():Dynamic
	{
		return {
			category: 'Camera',
			names: ['My Camera Event']
		};
	}

	public function customEvents():Dynamic
	{
		return {
			category: 'My Mod',
			names: ['My Custom Event', 'Another Custom Event']
		};
	}
}
