using BasicEngine;
using BasicEngine.Math;
using System;
namespace MincedFractals
{
	static
	{
		public static GameApp gGameApp;
	}

	class GameApp : BasicEngine.Engine
	{
		public SDLCamera mCam = new SDLCamera(2) ~ SafeDelete!(_);

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
