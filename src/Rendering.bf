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
		bool liveUpdate = false;

		overlayType showLabels = .reduce;
		enum overlayType : int
		{
			off = 0,
			all = 1,
			reduce = 2,
			superReduce = 3,

		}

		bool rerender = false;

		List<DataLabel<int64>> timerLabels = new List<DataLabel<int64>>() ~ DeleteContainerAndItems!(_);
		List<DataLabel<double>> graphDiscriptionsLabel = new List<DataLabel<double>>() ~ DeleteContainerAndItems!(_);
		DataLabel<bool> statusLabel = null ~ DeleteAndNullify!(_);
		bool lastStatus = false;
		Image lastStatusString = null ~ SafeDelete!(_);

		public this()
		{
			fc = new FractelChunkMultiThread(new .(gGameApp.mScreen.w, gGameApp.mScreen.h), -1.12, 1.12, -2.0, 0.47, 2, 200);

			setUpHud();

			fc.PreperRenderImages();

			kbManager.AddKey(.KpMinus, new (delta) =>
				{
					fc.[Friend]zoomScale = fc.[Friend]zoomScale / (1.25f * delta);
					Logger.Info("zoom", fc.[Friend]zoomScale);
					rerender = true;
					return 20;
				});

			kbManager.AddKey(.KpPlus, new (delta) =>
				{
					fc.[Friend]zoomScale *= (1.25f * delta);
					Logger.Info("zoom", fc.[Friend]zoomScale);
					rerender = true;
					return 20;
				});

			kbManager.AddKey(.K, new (delta) =>
				{
					fc.[Friend]yOffset -= (delta * 0.5) / fc.[Friend]zoomScale;
					Logger.Info("y", fc.[Friend]yOffset);
					rerender = true;
					return 20;
				});

			kbManager.AddKey(.U, new (delta) =>
				{
					fc.[Friend]kMax *= (1.25f * delta);

					Logger.Info("kMax", fc.[Friend]kMax);
					rerender = true;
					return 20;
				});

			kbManager.AddKey(.O, new (delta) =>
				{
					fc.[Friend]kMax = fc.[Friend]kMax / (1.25f * delta);
					Logger.Info("kMax", fc.[Friend]kMax);
					rerender = true;
					return 20;
				});

			kbManager.AddKey(.I, new (delta) =>
				{
					fc.[Friend]yOffset += (delta * 0.5) / fc.[Friend]zoomScale;
					Logger.Info("y", fc.[Friend]yOffset);
					rerender = true;
					return 20;
				});

			kbManager.AddKey(.J, new (delta) =>
				{
					fc.[Friend]xOffset -= (delta * 0.5) / fc.[Friend]zoomScale;
					Logger.Info("x", fc.[Friend]xOffset);
					rerender = true;
					return 20;
				});

			kbManager.AddKey(.L, new (delta) =>
				{
					fc.[Friend]xOffset += (delta * 0.5) / fc.[Friend]zoomScale;
					Logger.Info("x", fc.[Friend]xOffset);
					rerender = true;
					return 20;
				});

			kbManager.AddKey(.N, new (delta) =>
				{
					fc.SetMembers(-1.12, 1.12, -2.0, 0.47);
					fc.[Friend]xOffset = 0;
					fc.[Friend]yOffset = 0;
					Logger.Info("reset");
					rerender = true;
					return 20;
				});

			kbManager.AddKey(.R, new (delta) =>
				{
					fc.PreperRenderImages();
					return 20;
				});
			kbManager.AddKey(.B, new (delta) =>
				{
					liveUpdate = !liveUpdate;
					Logger.Info("mLiveUpdate", liveUpdate);
					return 20;
				});


			kbManager.AddKey(.H, new (delta) =>
				{
					if (delta == KeyboardManager.DELTA_Shift)
						showLabels--;
					else
						showLabels++;

					if (showLabels > overlayType.superReduce)
						showLabels = .off;
					else if (showLabels < 0)
						showLabels = .superReduce;

					Logger.Info("hideLabels", showLabels);
					return 21;
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
			int rowIndex = 0;
			{
				var label = new DataLabel<double>(&fc.[Friend]yMin, 4, 4 + (28 * (rowIndex++ + 1)));
				label.[Friend]mformatString = "yMin: {0:00}";
				label.ForceUpdateString();
				label.GroupId = 1;
				graphDiscriptionsLabel.Add(label);
			}
			{
				var label = new DataLabel<double>(&fc.[Friend]yMax, 4, 4 + (28 * (rowIndex++ + 1)));
				label.[Friend]mformatString = "yMax: {0:0}";
				label.ForceUpdateString();
				label.GroupId = 1;
				graphDiscriptionsLabel.Add(label);
			}
			{
				var label = new DataLabel<double>(&fc.[Friend]xMin, 4, 4 + (28 * (rowIndex++ + 1)));
				label.[Friend]mformatString = "xMin: {0:0}";
				label.ForceUpdateString();
				label.GroupId = 1;
				graphDiscriptionsLabel.Add(label);
			}
			{
				var label = new DataLabel<double>(&fc.[Friend]xMax, 4, 4 + (28 * (rowIndex++ + 1)));
				label.[Friend]mformatString = "xMax: {0:0}";
				label.GroupId = 1;
				label.ForceUpdateString();
				graphDiscriptionsLabel.Add(label);
			}
			{
				var label = new DataLabel<double>(&fc.[Friend]kMax, 4, 4 + (28 * (rowIndex++ + 1)));
				label.[Friend]mformatString = "kMax: {0:00}";
				label.GroupId = 2;
				label.ForceUpdateString();
				graphDiscriptionsLabel.Add(label);
			}
			{
				var label = new DataLabel<double>(&fc.[Friend]yOffset, 4, 4 + (28 * (rowIndex++ + 1)));
				label.[Friend]mformatString = "yOffset: {}";
				label.GroupId = 2;
				label.ForceUpdateString();
				graphDiscriptionsLabel.Add(label);
			}
			{
				var label = new DataLabel<double>(&fc.[Friend]xOffset, 4, 4 + (28 * (rowIndex++ + 1)));
				label.[Friend]mformatString = "xOffset: {}";
				label.GroupId = 2;
				label.ForceUpdateString();
				graphDiscriptionsLabel.Add(label);
			}
			{
				var label = new DataLabel<double>(&fc.[Friend]zoomScale, 4, 4 + (28 * (rowIndex++ + 1)));
				label.[Friend]mformatString = "zoomScale: {}";
				label.GroupId = 2;
				label.ForceUpdateString();
				graphDiscriptionsLabel.Add(label);
			}
			rowIndex++;
			for (var i in ..<fc.mRenderThreads.Count)
			{
				var label = new DataLabel<int64>(&fc.LastRenderingTimes[i + 1], 4, 4 + (28 * (rowIndex++ + 1)));
				label.GroupId = 3;
				label.AutoUpdate = false;

				label.ForceUpdateString();
				timerLabels.Add(label);
			}


			statusLabel = new DataLabel<bool>(null, 4, 4 + (28 * (rowIndex++ + 1)));
			statusLabel.[Friend]mformatString = "Rendering Done: {}";
			statusLabel.GroupId = 3;
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

			if (holdingMouseDown)
			{
				SDL2.SDL.Rect* rect = scope .();
				rect.x = (int32)zoomRec.mX;
				rect.y = (int32)zoomRec.mY;
				int32 mouseX = 0;
				int32 mouseY = 0;
				SDL.GetMouseState(&mouseX, &mouseY);
				rect.w = mouseX - (int32)zoomRec.mX;
				rect.h = mouseY - (int32)zoomRec.mY;
				SDL.SetRenderDrawColor(gGameApp.mRenderer, 255, 255, 255, 255);
				SDL.RenderDrawRect(gGameApp.mRenderer, rect);
				SDL.SetRenderDrawColor(gGameApp.mRenderer, 0, 0, 0, 255);
			}
			if (showLabels > 0)
			{
				for (var label in timerLabels)
				{
					label.Draw(dt);
				}

				for (var label in graphDiscriptionsLabel)
				{
					label.Draw(dt);
				}
				statusLabel.Draw(dt);
				if (lastError != SDL.GetError())
				{
					lastError = SDL.GetError();
					if (*lastError != (char8)0)
					{
						Logger.Error(scope String(lastError));
					}
				}
			}
		}

		public override void Update(int dt)
		{
			base.Update(dt);

			if (showLabels > 0)
			{
				int visiableLabelCnt = 0;

				for (var graphLabel in graphDiscriptionsLabel)
				{
					graphLabel.UpdateString(true);
					if (graphLabel.GroupId >= (int)showLabels)
					{
						graphLabel.mPos.mY = (28 * (visiableLabelCnt++ + 1));
						graphLabel.mVisiable = true;
					}
					else
					{
						graphLabel.mVisiable = false;
					}
				}
				if ((int)showLabels < 3)
					visiableLabelCnt++;
				for (var i in ..<timerLabels.Count)
				{
					var timerLabel = timerLabels[i];
					if (fc.mThreadEnabled[i])
					{
						if (timerLabel.UpdateString())
						{
							var threadAlive = fc.mRenderThreads[i].IsAlive;
							/*if (threadAlive)
								SafeMemberSet!(label.mColor, new Color(255, 32, 32));
							else
								SafeMemberSet!(label.mColor, new Color(64, 255, 64));*/

							var str = new System.String();
							str.AppendF("{}(R:{}) : {}", i + 1, threadAlive,
								TimeSpan((int64) * timerLabel.[Friend]mPointer));

							timerLabel.SetString(str);
						}
						timerLabel.mVisiable = true;
						timerLabel.mPos.mY = (28 * (visiableLabelCnt++ + 1));
					}
					else
					{
						timerLabel.mVisiable = false;
					}
				}

				statusLabel.UpdateString(fc.RenderingDone, true);
				statusLabel.mPos.mY = (28 * (visiableLabelCnt++ + 1));
			}
		}

		Vector2D zoomRec = new Vector2D(0, 0) ~ SafeDelete!(_);
		bool holdingMouseDown = false;
		public override void MouseDown(SDL2.SDL.MouseButtonEvent evt)
		{
			base.MouseDown(evt);
			if (!holdingMouseDown)
			{
				zoomRec.Set(evt.x, evt.y);
				holdingMouseDown = true;
			}
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
			holdingMouseDown = false;
			var myPixelManager = fc.GetScreenPixelManager();
			defer { SafeDeleteNullify!(myPixelManager); }
			var minPos = myPixelManager.GetAbsoluteMathsCoord(v2d<double>(zoomRec));
			var maxPos = myPixelManager.GetAbsoluteMathsCoord(v2d<double>(evt.x, evt.y));
			Logger.Debug(minPos.x, minPos.y);
			Logger.Debug(maxPos.x, maxPos.y);
			Logger.Debug(evt.x - zoomRec.mX, evt.y - zoomRec.mY);
			const int ZOOM_THREASHOLD = 5;
			if (evt.x - zoomRec.mX > ZOOM_THREASHOLD && evt.y - zoomRec.mY > ZOOM_THREASHOLD)
			{
				if (kbManager.KeyDown(.LShift))
				{
					fc.SetMembers(fc.[Friend]yMax * 2, fc.[Friend]yMin * 2, fc.[Friend]xMin * 2, fc.[Friend]xMax * 2, 1, fc.[Friend]kMax);
				} else
				{
					fc.SetMembers(maxPos.y, minPos.y, minPos.x, maxPos.x, 1, fc.[Friend]kMax);
				}
				fc.[Friend]xOffset = 0;
				fc.[Friend]yOffset = 0;
				fc.PreperRenderImages();
			}
			base.MouseUp(evt);
		}

		public override void HandleInput()
		{
			kbManager.HandleInput();
			var ret = kbManager.HandlePanAndZoom(gGameApp.mCam);

			if (ret > kbManager.KeyPressDelay)
				kbManager.KeyPressDelay = ret;

			if (liveUpdate && rerender)
			{
				fc.PreperRenderImages();
			}
			rerender = false;
		}
	}
}
