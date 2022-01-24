using BasicEngine.GameStates;
using BasicEngine;
//using BasicEngine.ANN;
using System;
using BasicEngine.LayeredList;
using System.Collections;
using BasicEngine.Debug;
using BasicEngine.Collections;
using BasicEngine.Rendering;
using BasicEngine.Entity;
using FractelOPOP.Entity;
using SDL2;
using System.Threading;
using BasicEngine.HUD;
namespace FractelOPOP
{
	class Rendering : GameState
	{
		//private List<FractelChunkMultiThread> fcList = new List<FractelChunkMultiThread>() ~ DeleteContainerAndItems!(_);
		private FractelChunkMultiThread fc = null ~ SafeDelete!(_);
		private KeyboardManager kbManager = new KeyboardManager() ~ SafeDelete!(_);
		//private FractelChunk fc = null ~ SafeDelete!(_);
		private double zoom = 1;
		bool mLiveUpdate = false;

		List<DataLabel<int64>> timerLabels = new List<DataLabel<int64>>() ~ DeleteContainerAndItems!(_);
		DataLabel<bool> statusLabel = null ~ DeleteAndNullify!(_);
		bool lastStatus = false;
		Image lastStatusString = null ~ SafeDelete!(_);
		public this()
		{
			for (var y in -1 ... 1)
			{
				for (var x in -1 ... 1)
				{
					//fcList.Add(new FractelChunk(new .(x, y), new .(gGameApp.mScreen.w / 2, gGameApp.mScreen.h / 2), 1));
				}
			}
			fc = new FractelChunkMultiThread(new .(gGameApp.mScreen.w, gGameApp.mScreen.h), -1.12, 1.12, -2.0, 0.47, 2, 200);
			//fc = new FractelChunk(new .(gGameApp.mScreen.w * 2, gGameApp.mScreen.h * 2), -2, 2, -2, 2, 2, 400);

			for (var i in ..<fc.mRenderThreads.Count)
			{
				//var label = new DataLabel<int64>(&fc.LastRenderingTimes[i + 1], 4, 4 + (28 * (i + 1)));
				//timerLabels.Add(label);
			}
			/*
			timerLabels.Add(new DataLabel<int64>(&fc.LastRenderingTimes[1], 4, 4 + (28 * 1)));
			timerLabels.Add(new DataLabel<int64>(&fc.LastRenderingTimes[3], 4, 4 + (28 * 2)));
			timerLabels.Add(new DataLabel<int64>(&fc.LastRenderingTimes[5], 4, 4 + (28 * 3)));*/
			statusLabel = new DataLabel<bool>(null, 4, 4 + (28 * (fc.mRenderThreads.Count + 1)));
			//statusLabel.[Friend]mformatString = "Rendering Done: {}";

			for (var label in timerLabels)
			{
				label.AutoUpdate = false;
				label.UpdateString(0, true);
			}

			fc.PreperRenderImages();
			/*for (var fc in fc)
			{
				Logger.Debug(StackStringFormat!("{} / {}", (++cnt), fc.Count));
				fc.PreperRenderImages();
			}*/
			//RenderAsVideo();


			kbManager.AddKey(.KpMinus, new (delta) =>
				{
					fc.[Friend]zoomScale = fc.[Friend]zoomScale / (1.25f * delta);
					Logger.Info("zoom", fc.[Friend]zoomScale);
					return 20;
				});

			kbManager.AddKey(.KpPlus, new (delta) =>
				{
					fc.[Friend]zoomScale *= 1.25f * delta;
					Logger.Info("zoom", fc.[Friend]zoomScale);
					return 20;
				});

			kbManager.AddKey(.K, new (delta) =>
				{
					fc.[Friend]yOffset -= (delta * 0.5) / fc.[Friend]zoomScale;
					Logger.Info("y", fc.[Friend]yOffset);
					return 20;
				});

			kbManager.AddKey(.I, new (delta) =>
				{
					fc.[Friend]yOffset += (delta * 0.5) / fc.[Friend]zoomScale;
					Logger.Info("y", fc.[Friend]yOffset);
					return 20;
				});

			kbManager.AddKey(.J, new (delta) =>
				{
					fc.[Friend]xOffset -= (delta * 0.5) / fc.[Friend]zoomScale;
					Logger.Info("x", fc.[Friend]xOffset);
					return 20;
				});

			kbManager.AddKey(.L, new (delta) =>
				{
					fc.[Friend]xOffset += (delta * 0.5) / fc.[Friend]zoomScale;
					Logger.Info("x", fc.[Friend]xOffset);
					return 20;
				});

			kbManager.AddKey(.N, new (delta) =>
				{
					fc.[Friend]xOffset = 0;
					fc.[Friend]yOffset = 0;
					fc.[Friend]zoomScale = 1;
					Logger.Info("reset", fc.[Friend]xOffset);
					return 20;
				});

			kbManager.AddKey(.R, new (delta) =>
				{
					fc.PreperRenderImages();
					return 20;
				});
			kbManager.AddKey(.B, new (delta) =>
				{
					mLiveUpdate = !mLiveUpdate;
					Logger.Info("mLiveUpdate", mLiveUpdate);
					return 20;
				});
			kbManager.AddKey(.F, new (delta) =>
				{
					gGameApp.mCam.Reset();
					return 20;
				});

			kbManager.AddKey(.Kp1, new (delta) =>
				{
					fc.mThreadEnabled[0] = !fc.mThreadEnabled[0];
					return 21;
				});

			kbManager.AddKey(.Kp2, new (delta) =>
				{
					fc.mThreadEnabled[1] = !fc.mThreadEnabled[1];
					return 21;
				});
			kbManager.AddKey(.Kp3, new (delta) =>
				{
					fc.mThreadEnabled[2] = !fc.mThreadEnabled[2];
					return 21;
				});
			kbManager.AddKey(.Kp4, new (delta) =>
				{
					fc.mThreadEnabled[3] = !fc.mThreadEnabled[3];
					return 21;
				});
			kbManager.AddKey(.Kp5, new (delta) =>
				{
					fc.mThreadEnabled[4] = !fc.mThreadEnabled[4];
					return 21;
				});
			kbManager.AddKey(.Kp6, new (delta) =>
				{
					fc.mThreadEnabled[5] = !fc.mThreadEnabled[5];
					return 21;
				});
			kbManager.AddKey(.Kp7, new (delta) =>
				{
					fc.mThreadEnabled[6] = !fc.mThreadEnabled[6];
					return 21;
				});
			kbManager.AddKey(.Kp8, new (delta) =>
				{
					fc.mThreadEnabled[7] = !fc.mThreadEnabled[7];
					return 21;
				});
			kbManager.AddKey(.Kp9, new (delta) =>
				{
					fc.mThreadEnabled[8] = !fc.mThreadEnabled[8];
					return 21;
				});
		}

		public ~this()
		{
		}

		private void setUpHud()
		{
		}

		private void RenderAsVideo()
		{
			/*uint8[] bitmap= scope uint8[fcList[0].[Friend]mImage.mSurface.pitch*fcList[0].[Friend]mImage.mSurface.h];
			SDL.RWOps *rw = SDL2.SDL.RWFromMem(bitmap, sizeof(bitmap));
			SDL2.SDL.SaveBMP_RW(sshot, rw, 1); */

			/*var s = fcList[0].[Friend]mImage.mSurface;
			SDL.SDL_SaveBMP()*/

			//SDL.RWOps* file = SDL.RWFromFile("33_file_reading_and_writing/nums.bin", "r+b");
			SDL.LockTexture(fc.[Friend]mCurrentImage.mTexture, null, var data, var pitch);
			SDL.RWOps* file = SDL.RWFromMem(data, pitch * fc.[Friend]mCurrentImage.mSurface.h * 4);
			if (file == null)
			{
				Logger.Warn("Warning: Unable to open file! SDL Error: ", SDL.GetError());

				//Create file for writing
				file = SDL.RWFromFile("33_file_reading_and_writing/nums.bin", "w+b");
			}
		}

		public char8* lastError;
		public override void Draw(int dt)
		{
			base.Draw(dt);
			fc.Draw();
			/*for (var i in ..<timerLabels.Count)
			{
				var label = timerLabels[i];
				label.Draw(dt);
				//if (label.[Friend]mLastStringValue != fc.LastRenderingTimes[i])
			}*/
			for (var label in timerLabels)
			{
				label.Draw(dt);
			}
			//statusLabel.Draw(dt);
			if (lastError != SDL.GetError())
			{
				lastError = SDL.GetError();
				if (*lastError != (char8)0)
				{
					Logger.Error(scope String(lastError));
				}
			}
		}

		public override void Update(int dt)
		{
			base.Update(dt);

			//statusLabel.UpdateString(fc.RenderingDone);
			for (var i in ..<timerLabels.Count)
			{
				var label = timerLabels[i];
				if (fc.mThreadEnabled[i])
				{
					if (label.UpdateString())
					{
						var str = new System.String();
						str.AppendF("{}(R:{}) : {}", i + 1, fc.mRenderThreads[i].IsAlive,
							TimeSpan((int64) * label.[Friend]mPointer));

						label.SetString(str);
					}
					label.mVisiable = true;
				}
				else
				{
					label.mVisiable = false;
				}
			}
			/*if (lastStatus != fc.RenderingDone)
			{
				lastStatus = fc.RenderingDone;
				if (lastStatusString != null)
					delete lastStatusString;
				lastStatusString = DrawUtils.GetStringOutlineImage(gEngineApp.mRenderer, gEngineApp.mFont, 8, 4 + (28 * 0), StackStringFormat!("Rendering Done: {}", (bool)lastStatus), .(64, 255, 192, 255));
			}*/
		}

		public override void MouseDown(SDL2.SDL.MouseButtonEvent evt)
		{
			base.MouseDown(evt);

			for (let entity in gEngineApp.mEntityList.mLayers[(int)LayeredList.LayerNames.HUD].mEntities)
			{
				if (let button = entity as BasicEngine.HUD.Button)
				{
					if ((button.mBoundingBox.Contains((.)(evt.x - entity.mPos.mX), (.)(evt.y - entity.mPos.mY))) && (button.mEnabled && button.mVisiable))
					{
						button.onClick();
					}
				}
			}
		}

		public override void MouseUp(SDL2.SDL.MouseButtonEvent evt)
		{
			base.MouseUp(evt);
		}

		public override void HandleInput()
		{
			kbManager.HandleInput();
			var delay = kbManager.KeyPressDelay;
			//var delta = kbManager.getDelta();


			/*kbManager.AddKey(.C, new (delta) =>
				{
					fc.[Friend]xyPixelStep = Math.Max(fc.[Friend]xyPixelStep - 1, 1);
					Logger.Info("pixelstep", fc.[Friend]xyPixelStep);
					return 20;
				});*/


			/*else if (gGameApp.IsKeyDown(.X))
			{
				//for (var fc in fc)
				//{
				fc.[Friend]xyPixelStep++;
				Logger.Info("pixelstep", fc.[Friend]xyPixelStep);
				//}
				delay = 20;
			}*/



			var ret = kbManager.HandlePanAndZoom(gGameApp.mCam);

			if (ret > delay)
				delay = ret;


			if (delay == 20)
			{
				if (mLiveUpdate)
				{
					fc.PreperRenderImages();
				}
			}
		}
	}
}
