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
using MincedFractals.Entity;
using SDL2;
using System.Threading;
using BasicEngine.HUD;
using System.IO;
using BasicEngine.Math;
using BasicEngine.Options;
using MincedFractals.Entity.FractalThreads;
using MincedFractals.Math;
namespace MincedFractals
{
	class Rendering : GameState
	{
		//private List<FractelChunkMultiThread> fcList = new List<FractelChunkMultiThread>() ~ DeleteContainerAndItems!(_);
		private FractalChunkMultiThread fc = null ~ SafeDelete!(_);
		private KeyboardManager kbManager = new KeyboardManager() ~ SafeDelete!(_);
		OptionsHandler mOptionsHandler = new OptionsHandler() ~ SafeDelete!(_);
		//private FractelChunk fc = null ~ SafeDelete!(_);
		bool liveUpdate = true;

		overlayType showLabels = .superReduce;
		enum overlayType : int
		{
			off = 0,
			all = 1,
			reduce = 2,
			superReduce = 3,

		}

		bool rerender = false;
		bool saveAnimation = false;

		List<DataLabel<int64>> timerLabels = new List<DataLabel<int64>>() ~ DeleteContainerAndItems!(_);
		List<DataLabel<double>> graphDiscriptionsLabel = new List<DataLabel<double>>() ~ DeleteContainerAndItems!(_);
		DataLabel<bool> statusLabel = null ~ DeleteAndNullify!(_);
		DataLabel<int64> animationLabel = null ~ DeleteAndNullify!(_);
		bool lastStatus = false;
		Image lastStatusString = null ~ SafeDelete!(_);

		public this()
		{
			if (!System.IO.Directory.Exists("./png"))
			{
				System.IO.Directory.CreateDirectory("./png");
			}
			if (!System.IO.Directory.Exists("./png/ani"))
			{
				System.IO.Directory.CreateDirectory("./png/ani");
			}

			if (!mOptionsHandler.ExistOption("saving"))
				mOptionsHandler.WriteOption("saving", "false");
			else
			{
				switch (Boolean.Parse(mOptionsHandler.ReadOption<bool>("saving").Value))
				{
				case .Ok(let val):
					saveAnimation = val;
				case .Err(let err):
					saveAnimation = false;
				}
			}
			fc = new FractalChunkMultiThread(new .(gGameApp.mScreen.w, gGameApp.mScreen.h), -1.12, 1.12, -2.0, 0.47);

			setUpHud();

			fc.StartRenderThreads();


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


			kbManager.AddKey(.Period, new (delta) =>
				{
					fc.mAnimationThread.StopAnimation();
					fc.mAnimationThread.CopyGraphHistory(fc.[Friend]undoHistory);
					fc.mAnimationThread.animationHistory.Add(fc.[Friend]currentGraphParameters);
					//fc.mAnimationThread.SmoothAnimation(0.1f);
					fc.mAnimationThread.SmoothAnimation(20, 1);
					fc.mAnimationThread.StartAnimation(saveAnimation);
					Logger.Info("Start Animation");

					return 20;
				});

			kbManager.AddKey(.X, new (delta) =>
				{
					fc.mAnimationThread.StopAnimation();
					//fc.mAnimationThread.CopyGraphHistory(fc.[Friend]undoHistory);
					fc.mAnimationThread.animationHistory.Clear();
					fc.mAnimationThread.animationHistory.Add(fc.[Friend]undoHistory[0]);
					fc.mAnimationThread.animationHistory.Add(fc.[Friend]currentGraphParameters);
					//fc.mAnimationThread.SmoothAnimation(0.1f);
					fc.mAnimationThread.SmoothAnimation(20, 1);
					fc.mAnimationThread.StartAnimation(saveAnimation);
					Logger.Info("Start Animation");

					return 20;
				});

			kbManager.AddKey(.Comma, new (delta) =>
				{
					fc.mAnimationThread.StopAnimation();
					Logger.Info("Stop Animation");

					return 20;
				});

			kbManager.AddKey(.V, new (delta) =>
				{
					fc.[Friend]undoHistory.Clear();
					Logger.Info("Clear undoHistory");

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
					fc.SetGraphParameters(-1.12, 1.12, -2.0, 0.47);
					fc.[Friend]currentGraphParameters.xOffset = 0;
					fc.[Friend]currentGraphParameters.yOffset = 0;
					Logger.Info("reset");
					rerender = true;
					return 20;
				});

			kbManager.AddKey(.R, new (delta) =>
				{
					fc.StartRenderThreads();
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
					fc.mRenderThreads[0].Enabled = !fc.mRenderThreads[0].Enabled;
					return 21;
				});

			kbManager.AddKey(.Kp2, new (delta) =>
				{
					fc.mRenderThreads[1].Enabled = !fc.mRenderThreads[1].Enabled;
					return 21;
				});
			kbManager.AddKey(.Kp3, new (delta) =>
				{
					fc.mRenderThreads[2].Enabled = !fc.mRenderThreads[2].Enabled;
					return 21;
				});
			kbManager.AddKey(.Kp4, new (delta) =>
				{
					fc.mRenderThreads[3].Enabled = !fc.mRenderThreads[3].Enabled;
					return 21;
				});
			kbManager.AddKey(.Kp5, new (delta) =>
				{
					fc.mRenderThreads[4].Enabled = !fc.mRenderThreads[4].Enabled;
					return 21;
				});
			kbManager.AddKey(.Kp6, new (delta) =>
				{
					fc.mRenderThreads[5].Enabled = !fc.mRenderThreads[5].Enabled;
					return 21;
				});
			kbManager.AddKey(.Kp7, new (delta) =>
				{
					fc.mRenderThreads[6].Enabled = !fc.mRenderThreads[6].Enabled;
					return 21;
				});
			kbManager.AddKey(.Kp8, new (delta) =>
				{
					fc.mRenderThreads[7].Enabled = !fc.mRenderThreads[7].Enabled;
					return 21;
				});
			kbManager.AddKey(.Kp9, new (delta) =>
				{
					//fc.mRenderThreads[8].Enabled = !fc.mRenderThreads[8].Enabled;
					return 21;
				});
		}

		public ~this()
		{
		}

		private void setUpHud()
		{
			gGameApp.SetTitle("Minced Fractals");
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
				label.GroupId = 1;
				label.ForceUpdateString();
				graphDiscriptionsLabel.Add(label);
			}
			rowIndex++;
			for (var i in ..<fc.mRenderThreads.Count)
			{
				var label = new DataLabel<int64>(&fc.mRenderThreads[i].[Friend]_renderTime, 4, 4 + (28 * (rowIndex++ + 1)));
				label.GroupId = 3;
				label.AutoUpdate = false;

				label.ForceUpdateString();
				timerLabels.Add(label);
			}
			{
				var label = new DataLabel<int64>(&fc.mAnimationThread.[Friend]_renderThread.[Friend]_renderTime, 4, 4 + (28 * (rowIndex++ + 1)));
				label.GroupId = 3;
				label.AutoUpdate = false;
				label.ForceUpdateString();
				animationLabel = label;
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

		public override void HandleEvent(SDL.Event evt)
		{
			base.HandleEvent(evt);
			switch (evt.type)
			{
			case .DropFile:
				var dropped_filedir = scope String(evt.drop.file);
				StreamReader sr = scope .();
				if (sr.Open(dropped_filedir) case .Err(let err))
				{
					SDL.SimpleMessageBox(
						SDL.MessageBoxFlags.Error,
						"Error in Parsing File",
						dropped_filedir,
						gGameApp.mWindow);
					return;
				}
				List<String> lbuffer = new List<String>();
				for (var line in sr.Lines)
					lbuffer.Add(new String(line.Value));

				var gp = GraphParameters();
				gp.Parse(lbuffer);
				fc.SetGraphParameters(gp);
				fc.StartRenderThreads();
				DeleteContainerAndItems!(lbuffer);
				//delete evt.drop.file;// Crash!?!?

			default:
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
				SDL.SetRenderDrawColor(gGameApp.mRenderer, 255, 255, 255, 255);
				SDL.Rect* rect = scope .((int32)zoomRect.x, (int32)zoomRect.y, (int32)zoomRect.w, (int32)zoomRect.h);
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
				animationLabel.Draw(dt);
				statusLabel.Draw(dt);
				if (lastError != SDL.GetError())
				{
					lastError = SDL.GetError();
					if (*lastError != (char8)0)
					{
						Logger.Error(scope String(lastError));
					}
				}

				/*SDL.SetRenderDrawColor(gGameApp.mRenderer, 255, 255, 255, 255);
				SDL.RenderDrawRect(gGameApp.mRenderer, &fc.mAnimationThread.[Friend]_targetRect);
				SDL.SetRenderDrawColor(gGameApp.mRenderer, 0, 0, 0, 255);*/
			}
		}

		public override void Update(int dt)
		{
			base.Update(dt);
			if (fc.mAnimationThread.[Friend]animationRunning)
			{
				fc.mAnimationThread.AnimateHistory();
			}
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
					if (fc.mRenderThreads[i].Enabled && !fc.mAnimationThread.[Friend]animationRunning)
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
				if (animationLabel.GroupId >= (int)showLabels && fc.mAnimationThread.[Friend]animationRunning)
				{
					animationLabel.[Friend]mPointer = &fc.mAnimationThread.[Friend]_renderThread.[Friend]_renderTime;
					if (animationLabel.UpdateString())
					{
						var threadAlive = fc.mAnimationThread.IsAlive;
						/*if (threadAlive)
							SafeMemberSet!(label.mColor, new Color(255, 32, 32));
						else
							SafeMemberSet!(label.mColor, new Color(64, 255, 64));*/

						var str = new System.String();
						str.AppendF("Anim({})({}/{}){} : {}", threadAlive ? "Running" : "Idle",
							fc.mAnimationThread.[Friend]animationIndex, fc.mAnimationThread.animationHistory.Count,
							fc.mAnimationThread.[Friend]saveAnimation ? "(Save!)" : "",
							TimeSpan((int64) * animationLabel.[Friend]mPointer));

						animationLabel.SetString(str);
					}
					animationLabel.mPos.mY = (28 * (visiableLabelCnt++ + 1));
					animationLabel.mVisiable = true;
				}
				else
				{
					animationLabel.mVisiable = false;
				}
				if (!fc.mAnimationThread.[Friend]animationRunning)
				{
					statusLabel.UpdateString(fc.RenderingDone, true);
					statusLabel.mPos.mY = (28 * (visiableLabelCnt++ + 1));
					statusLabel.mVisiable = true;
				}
				else
				{
					statusLabel.mVisiable = false;
				}
			}

			if (holdingMouseDown)
			{
				zoomRect.x = startClickPos.mX;
				zoomRect.y = startClickPos.mY;
				int32 mouseX = 0;
				int32 mouseY = 0;
				SDL.GetMouseState(&mouseX, &mouseY);

				if (kbManager.KeyDown(.LShift))
				{
					zoomRect.x = (float)gGameApp.mScreen.w / 2;
					zoomRect.y = (float)gGameApp.mScreen.h / 2;
					zoomRect.y += 0.5d;
				}


				if (kbManager.KeyDown(.LAlt))
				{
					zoomRect.w = Math.Abs(mouseX - startClickPos.mX) * 2;
					zoomRect.h = Math.Abs(mouseY - startClickPos.mY) * 2;
					zoomRect.x = zoomRect.x - (zoomRect.w / 2);
					zoomRect.y = zoomRect.y - (zoomRect.h / 2);
				}

				else if (kbManager.KeyDown(.LCtrl))
				{
					zoomRect.w = mouseX - zoomRect.x;
					zoomRect.h = mouseY - zoomRect.y;
				}
				else
				{
					double w = (mouseX - zoomRect.x);

					float scale = ((float)gGameApp.mScreen.h / (float)gGameApp.mScreen.w);
					double h = (w * scale);

					zoomRect.w = (w * 2);
					zoomRect.h = (h * 2);
					zoomRect.x = (zoomRect.x - ((float)zoomRect.w / 2));
					zoomRect.y = (zoomRect.y - ((float)zoomRect.h / 2));
				}
			}
		}

		Vector2D startClickPos = new Vector2D(0, 0) ~ SafeDelete!(_);
		Rect<double> zoomRect = Rect<double>();
		bool holdingMouseDown = false;
		public override void MouseDown(SDL2.SDL.MouseButtonEvent evt)
		{
			base.MouseDown(evt);
			if (!holdingMouseDown && !fc.mAnimationThread.[Friend]animationRunning)
			{
				startClickPos.Set(evt.x, evt.y);
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
			if (!holdingMouseDown)
				return;
			holdingMouseDown = false;

			const int ZOOM_THREASHOLD = 5;
			//Size2D RecSize = scope .(zoomRect.h, zoomRect.w);

			var myPixelManager = fc.GetScreenPixelManager();
			defer { SafeDeleteNullify!(myPixelManager); }

			Rect<double> destRect = gGameApp.mCam.GetScaled(zoomRect);
			v2d<double> bufferZoomRec = gGameApp.mCam.GetProjected(v2d<double>(destRect.x, destRect.y));
			v2d<double> bufferZoomRec2 = gGameApp.mCam.GetProjected(v2d<double>(destRect.x + destRect.w, destRect.y + destRect.h));

			if (zoomRect.w < -ZOOM_THREASHOLD)
			{
				Swap!(bufferZoomRec.x, bufferZoomRec2.x);
			}
			if (zoomRect.h < -ZOOM_THREASHOLD)
			{
				Swap!(bufferZoomRec.y, bufferZoomRec2.y);
			}
			var minPos = myPixelManager.GetAbsoluteMathsCoord(bufferZoomRec);
			var maxPos = myPixelManager.GetAbsoluteMathsCoord(bufferZoomRec2);
			/*var width = Math.Abs(maxPos.x) + Math.Abs(minPos.x);
			var height = Math.Abs(maxPos.y) + Math.Abs(minPos.y);
			Logger.Debug(height / width);*/
			/*if (kbManager.KeyDown(.LCtrl))
			{
				/*var scalingY = fc.[Friend]currentGraphParameters.yMax / yMax;
				var scalingX = fc.[Friend]currentGraphParameters.xMax / maxPos.x;

				maxPos.y = maxPos.y / scalingY;
				maxPos.x = maxPos.y / scalingX;*/

				var graphH = Math.Abs(fc.[Friend]currentGraphParameters.yMax) +
			Math.Abs(fc.[Friend]currentGraphParameters.yMin); var graphW =
			Math.Abs(fc.[Friend]currentGraphParameters.xMax) + Math.Abs(fc.[Friend]currentGraphParameters.xMin); float
			scale = ((float)graphH / (float)graphW);

				var width = Math.Abs(maxPos.x) + Math.Abs(minPos.x);
				var height = Math.Abs(maxPos.y) + Math.Abs(minPos.y);

				if (maxPos.x > maxPos.y)
				{
					height = (int32)(width * scale);
				}
				else
				{
					width = (int32)(height * scale);
				}


				minPos.x -= width / 2;
				minPos.y -= height / 2;
			}*/

			Logger.Debug(minPos.x, minPos.y);
			Logger.Debug(maxPos.x, maxPos.y);
			Logger.Debug(evt.x - bufferZoomRec.y, evt.y - bufferZoomRec.y);

			if (evt.button == 3)//Right click
			{
				fc.Undo();
				fc.StartRenderThreads();
			} else if ((zoomRect.w > ZOOM_THREASHOLD || zoomRect.w < -ZOOM_THREASHOLD) && (zoomRect.h < -ZOOM_THREASHOLD || zoomRect.h > ZOOM_THREASHOLD))
			{
				if (maxPos.y < minPos.y)
					Swap!(maxPos.y, minPos.y);
				if (maxPos.x < minPos.x)
					Swap!(maxPos.x, minPos.x);
				fc.SetGraphParameters(minPos.y, maxPos.y, minPos.x, maxPos.x);
				fc.[Friend]currentGraphParameters.xOffset = 0;
				fc.[Friend]currentGraphParameters.yOffset = 0;
				fc.StartRenderThreads();
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
				fc.StartRenderThreads();
			}
			rerender = false;
		}
	}
}
