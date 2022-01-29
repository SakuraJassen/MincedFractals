using BasicEngine;
using BasicEngine.Collections;
using BasicEngine.Debug;
using System.Collections;
using System;

namespace MincedFractals
{
	class Program
	{
		public static void Main()
		{
			let gameApp = scope GameApp();
			gameApp.Init();

			delete gameApp.mGameState;
			gGameApp.mGameState = new Rendering();

			gameApp.Run();
		}
	}
}