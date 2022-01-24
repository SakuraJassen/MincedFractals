using BasicEngine;
namespace FractelOPOP
{
	static
	{
		public static GameApp gGameApp;
	}

	class GameApp : BasicEngine.Engine
	{
		public SDLCamera mCam = new SDLCamera() ~ SafeDelete!(_);

		public static class GameRules
		{
			//public static NamedIndex CanGrow = null;
		}

		public this()
		{
			gGameApp = this;
		}
	}
}
