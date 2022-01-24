using BasicEngine;
using BasicEngine.Collections;
using BasicEngine.Debug;
using System.Collections;
using System;

namespace FractelOPOP
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

/*using System;
using System.Diagnostics;
using BasicEngine.Collections;

namespace Testingstuff
{
	class Program
	{
		public static void Main()
		{
			/*var map = scope BasicEngine.Collections.BitArray();
			/*map.mNamedIndices.Add("test", 2, 7);
			map.mNamedIndices.Add("test2", 9, 12);
			map.mNamedIndices.Add("versionBit", 0);
			map.mNamedIndices.Add("das", 12);
			map.mNamedIndices.Add("dersion", 7);
			map.mNamedIndices.Add("boop", 1);*/

			map.mNamedIndices.AddSized("version", .Byte);
			map.mNamedIndices.AddSized("das", .Nibble);
			map.mNamedIndices.AddSized("das2", .Nibble);

			map.mNamedIndices.Sort();

			for(var ni in map.mNamedIndices.[Friend]mNamedIndices)
			{
				String strBuffer = scope .();
				ni.ToString(strBuffer);
				Log!(strBuffer);
			}

			map.SetByte(0, 0b0000'0000);
			map.SetByte(1, 0b1010'0101);
			System.Math.PrintNumberBin(map.GetByte(0), 8, false);
			map.SetRange(map.mNamedIndices.FindByName("version").Value, 0b1001'0110);
			System.Diagnostics.Debug.WriteLine();

			PrintNI(map, "version");
			PrintNI(map, "das");
			PrintNI(map, "das2");
			System.Diagnostics.Debug.WriteLine();*/
		}

		public static void PrintNI(BitArray map, String name)
		{
			var ni = map.mNamedIndices.FindByName(name).Value;
			Log!(ni.mName, ni.mStartIndex, ni.mEndIndex);
			var number = map.GetRange(ni);
			Debug.WriteLine(scope String()..AppendF("{}", number));
			System.Math.PrintNumberBin(number, ni.Size, false);
		}
	}
}
*/
