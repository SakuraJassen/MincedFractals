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
using System.IO;
namespace FractelOPOP
{
	class Rendering : GameState
	{
		//private List<FractelChunkMultiThread> fcList = new List<FractelChunkMultiThread>() ~ DeleteContainerAndItems!(_);
		private FractelChunkMultiThread fc = null ~ SafeDelete!(_);
		private KeyboardManager kbManager = new KeyboardManager() ~ SafeDelete!(_);
		//private FractelChunk fc = null ~ SafeDelete!(_);
		bool liveUpdate = true;

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
			fc = new FractelChunkMultiThread(new .(gGameApp.mScreen.w, gGameApp.mScreen.h), -1.12, 1.12, -2.0, 0.47, 700);

			setUpHud();

			fc.PreperRenderImages();

			kbManager.AddKey(.KpMinus, new (delta) =>
				{
					fc.[Friend]currentGraphParameters.zoomScale = fc.[Friend]currentGraphParameters.zoomScale / (1.25f * delta);
					Logger.Info("zoom", fc.[Friend]currentGraphParameters.zoomScale);
					rerender = true;
					return 20;
				});

			kbManager.AddKey(.KpPlus, new (delta) =>
				{
					fc.[Friend]currentGraphParameters.zoomScale *= (1.25f * delta);
					Logger.Info("zoom", fc.[Friend]currentGraphParameters.zoomScale);
					rerender = true;
					return 20;
				});


			kbManager.AddKey(.U, new (delta) =>
				{
					fc.[Friend]currentGraphParameters.kMax += (10f * delta);

					Logger.Info("kMax", fc.[Friend]currentGraphParameters.kMax);
					rerender = true;
					return 20;
				});

			kbManager.AddKey(.O, new (delta) =>
				{
					fc.[Friend]currentGraphParameters.kMax -= (10f * delta);
					if (fc.[Friend]currentGraphParameters.kMax < 1)
						fc.[Friend]currentGraphParameters.kMax = 1;
					Logger.Info("kMax", fc.[Friend]currentGraphParameters.kMax);
					rerender = true;
					return 20;
				});

			kbManager.AddKey(.K, new (delta) =>
				{
					fc.[Friend]currentGraphParameters.yOffset += ((fc.[Friend]currentGraphParameters.yMin - fc.[Friend]currentGraphParameters.yMax) * 0.1 * delta) / fc.[Friend]currentGraphParameters.zoomScale;
					Logger.Info("y", fc.[Friend]currentGraphParameters.yOffset);
					rerender = true;
					return 20;
				});

			kbManager.AddKey(.I, new (delta) =>
				{
					fc.[Friend]currentGraphParameters.yOffset -= ((fc.[Friend]currentGraphParameters.yMin - fc.[Friend]currentGraphParameters.yMax) * 0.1 * delta) / fc.[Friend]currentGraphParameters.zoomScale;
					Logger.Info("y", fc.[Friend]currentGraphParameters.yOffset);
					rerender = true;
					return 20;
				});

			kbManager.AddKey(.J, new (delta) =>
				{
					fc.[Friend]currentGraphParameters.xOffset += ((fc.[Friend]currentGraphParameters.yMin - fc.[Friend]currentGraphParameters.yMax) * 0.1 * delta) / fc.[Friend]currentGraphParameters.zoomScale;
					Logger.Info("x", fc.[Friend]currentGraphParameters.xOffset);
					rerender = true;
					return 20;
				});

			kbManager.AddKey(.L, new (delta) =>
				{
					fc.[Friend]currentGraphParameters.xOffset -= ((fc.[Friend]currentGraphParameters.xMin - fc.[Friend]currentGraphParameters.xMax) * 0.1 * delta) / fc.[Friend]currentGraphParameters.zoomScale;
					Logger.Info("x", fc.[Friend]currentGraphParameters.xOffset);
					rerender = true;
					return 20;
				});

			kbManager.AddKey(.N, new (delta) =>
				{
					fc.SetMembers(-1.12, 1.12, -2.0, 0.47);
					fc.[Friend]currentGraphParameters.xOffset = 0;
					fc.[Friend]currentGraphParameters.yOffset = 0;
					Logger.Info("reset");
					rerender = true;
					return 20;
				});

			kbManager.AddKey(.R, new (delta) =>
				{
					fc.PreperRenderImages();
					return 20;
				});

			kbManager.AddKey(.Z, new (delta) =>
				{
					fc.Undo();
					rerender = true;
					return 20;
				});

			kbManager.AddKey(.F10, new (delta) =>
				{
					var basename = scope String();
					basename.AppendF(".\\png\\{}{}{}-{}{}{}", DateTime.Now.Day, DateTime.Now.Month, DateTime.Now.Year, DateTime.Now.Hour, DateTime.Now.Minute, DateTime.Now.Second);
					SDLError!(fc.[Friend]mCurrentImage.SaveTexture(StackStringFormat!("{}.png", basename), gGameApp.mRenderer));

					StreamWriter sw = scope .();
					sw.Create(StackStringFormat!("{}.txt", basename));
					sw.WriteLine(ToStackString!(fc.[Friend]currentGraphParameters.yMin));
					sw.WriteLine(ToStackString!(fc.[Friend]currentGraphParameters.yMax));
					sw.WriteLine(ToStackString!(fc.[Friend]currentGraphParameters.xMin));
					sw.WriteLine(ToStackString!(fc.[Friend]currentGraphParameters.xMax));
					sw.WriteLine(ToStackString!(fc.[Friend]currentGraphParameters.kMax));
					sw.WriteLine(ToStackString!(fc.[Friend]currentGraphParameters.zoomScale));
					return 20;
				});

			kbManager.AddKey(.KpDivide, new (delta) =>
				{
					fc.[Friend]colourTable.Smooth();
					rerender = true;
					return 20;
				});

			kbManager.AddKey(.KpMultiply, new (delta) =>
				{
					SafeMemberSet!(fc.[Friend]colourTable, new ColourTable(400));
					rerender = true;
					return 20;
				});
			kbManager.AddKey(.Y, new (delta) =>
				{
					fc.Undo();
					rerender = true;
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
				var label = new DataLabel<double>(&fc.[Friend]currentGraphParameters.yMin, 4, 4 + (28 * (rowIndex++ + 1)));
				label.[Friend]mformatString = "yMin: {0:00}";
				label.ForceUpdateString();
				label.GroupId = 1;
				graphDiscriptionsLabel.Add(label);
			}
			{
				var label = new DataLabel<double>(&fc.[Friend]currentGraphParameters.yMax, 4, 4 + (28 * (rowIndex++ + 1)));
				label.[Friend]mformatString = "yMax: {0:0}";
				label.ForceUpdateString();
				label.GroupId = 1;
				graphDiscriptionsLabel.Add(label);
			}
			{
				var label = new DataLabel<double>(&fc.[Friend]currentGraphParameters.xMin, 4, 4 + (28 * (rowIndex++ + 1)));
				label.[Friend]mformatString = "xMin: {0:0}";
				label.ForceUpdateString();
				label.GroupId = 1;
				graphDiscriptionsLabel.Add(label);
			}
			{
				var label = new DataLabel<double>(&fc.[Friend]currentGraphParameters.xMax, 4, 4 + (28 * (rowIndex++ + 1)));
				label.[Friend]mformatString = "xMax: {0:0}";
				label.GroupId = 1;
				label.ForceUpdateString();
				graphDiscriptionsLabel.Add(label);
			}
			{
				var label = new DataLabel<double>(&fc.[Friend]currentGraphParameters.kMax, 4, 4 + (28 * (rowIndex++ + 1)));
				label.[Friend]mformatString = "kMax: {0:00}";
				label.GroupId = 2;
				label.ForceUpdateString();
				graphDiscriptionsLabel.Add(label);
			}
			{
				var label = new DataLabel<double>(&fc.[Friend]currentGraphParameters.yOffset, 4, 4 + (28 * (rowIndex++ + 1)));
				label.[Friend]mformatString = "yOffset: {}";
				label.GroupId = 2;
				label.ForceUpdateString();
				graphDiscriptionsLabel.Add(label);
			}
			{
				var label = new DataLabel<double>(&fc.[Friend]currentGraphParameters.xOffset, 4, 4 + (28 * (rowIndex++ + 1)));
				label.[Friend]mformatString = "xOffset: {}";
				label.GroupId = 2;
				label.ForceUpdateString();
				graphDiscriptionsLabel.Add(label);
			}
			{
				var label = new DataLabel<double>(&fc.[Friend]currentGraphParameters.zoomScale, 4, 4 + (28 * (rowIndex++ + 1)));
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
				var myPixelManager = fc.GetScreenPixelManager();
				defer { SafeDeleteNullify!(myPixelManager); }
				SDL2.SDL.Rect* rect = scope .();
				rect.x = (int32)zoomRec.mX;
				rect.y = (int32)zoomRec.mY;
				int32 mouseX = 0;
				int32 mouseY = 0;
				SDL.GetMouseState(&mouseX, &mouseY);
				//var maxPos = myPixelManager.GetAbsoluteMathsCoord(v2d<double>(mouseX, mouseY));

				if (kbManager.KeyDown(.LCtrl))
				{
					/*var scalingY = Math.Abs(fc.[Friend]currentGraphParameters.yMax / fc.[Friend]currentGraphParameters.yMin);
					var scalingX = Math.Abs(fc.[Friend]currentGraphParameters.xMax / fc.[Friend]currentGraphParameters.xMin);*/
					rect.w = (mouseX - (int32)zoomRec.mX) * 2;
					rect.h = (mouseY - (int32)zoomRec.mY) * 2;
					rect.y -= rect.h / 2;
					rect.x -= rect.w / 2;
				} else
				{
					rect.w = mouseX - (int32)zoomRec.mX;
					rect.h = mouseY - (int32)zoomRec.mY;
				}
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

			const int ZOOM_THREASHOLD = 5;
			Size2D RecSize = scope .(evt.x - zoomRec.mX, evt.y - zoomRec.mY);

			var myPixelManager = fc.GetScreenPixelManager();
			defer { SafeDeleteNullify!(myPixelManager); }

			var bufferZoomRec = v2d<double>(zoomRec);
			var bufferZoomRec2 = v2d<double>(evt.x, evt.y);

			if (RecSize.Width < -ZOOM_THREASHOLD)
			{
				Swap!(bufferZoomRec.x, bufferZoomRec2.x);
			}
			if (RecSize.Height < -ZOOM_THREASHOLD)
			{
				Swap!(bufferZoomRec.y, bufferZoomRec2.y);
			}
			var minPos = myPixelManager.GetAbsoluteMathsCoord(bufferZoomRec);
			var maxPos = myPixelManager.GetAbsoluteMathsCoord(bufferZoomRec2);

			if (kbManager.KeyDown(.LCtrl))
			{
				/*var scalingY = fc.[Friend]currentGraphParameters.yMax / yMax;
				var scalingX = fc.[Friend]currentGraphParameters.xMax / maxPos.x;

				maxPos.y = maxPos.y / scalingY;
				maxPos.x = maxPos.y / scalingX;*/

				var width = (maxPos.x - minPos.x) * 2;
				var height = (maxPos.y - minPos.y) * 2;
				minPos.x -= width / 2;
				minPos.y -= height / 2;
			}

			Logger.Debug(minPos.x, minPos.y);
			Logger.Debug(maxPos.x, maxPos.y);
			Logger.Debug(evt.x - bufferZoomRec.y, evt.y - bufferZoomRec.y);

			if (kbManager.KeyDown(.LShift) || evt.button == 3)//Rightclick
			{
				fc.Undo();
				fc.PreperRenderImages();
			} else if ((RecSize.Width > ZOOM_THREASHOLD || RecSize.Width < -ZOOM_THREASHOLD) && (RecSize.Height < -ZOOM_THREASHOLD || RecSize.Height > ZOOM_THREASHOLD))
			{
				fc.SetMembers(maxPos.y, minPos.y, minPos.x, maxPos.x, fc.[Friend]currentGraphParameters.kMax);
				fc.[Friend]currentGraphParameters.xOffset = 0;
				fc.[Friend]currentGraphParameters.yOffset = 0;
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
