using BasicEngine;
using System.Diagnostics;
using SDL2;
using BasicEngine.Debug;
using System;
using System.Collections;
using System.Threading;
using System.Threading.Tasks;
using MincedFractals.Entity.FractelOPOP.Entity.FractelChunk;

namespace MincedFractals.Entity
{
	class FractelChunkMultiThread
	{
		Vector2D mChunkPos = null ~ SafeDelete!(_);

		private uint32 mDrawCycle = 0;
		private bool autoUpdateDepth = true;

		GraphParameters currentGraphParameters = .();
		List<GraphParameters> undoHistory = new List<GraphParameters>() ~ SafeDelete!(_);

		private ColourTable colourTable = null ~ SafeDelete!(_);// Colour table.

		volatile private Image mCurrentImage = null;//~ SafeDelete!(_);
		//volatile private Image[] lImages = new Image[16]() ~ DeleteContainerAndItems!(_);
		private Size2D mSize ~ SafeDelete!(_);

		public List<RenderThread> mRenderThreads = new List<RenderThread>() ~ DeleteContainerAndItems!(_);
		public AnimationThread mAnimationThread = new AnimationThread(this) ~ SafeDelete!(_);
		/*public List<Thread> mRenderThreads = new List<Thread>() ~ DeleteContainerAndItems!(_);
		volatile public bool[] mThreadEnabled = null ~ SafeDelete!(_);
		volatile private bool savingImage = false;
		volatile private int64[] lastRenderingTime = new int64[16]() ~ SafeDelete!(_);*/

		public bool RenderingDone
		{
			get
			{
				for (var t in mRenderThreads)
				{
					if (t.IsAlive == true)
						return false;
				}
				return true;
			}
		}

		public this(Size2D size, double yMinimum, double yMaximum, double xMinimum, double xMaximum, int32 kMaximum = 200, int zoomS = 1)
		{
			mSize = size;
			currentGraphParameters.yMin = yMinimum;
			currentGraphParameters.yMax = yMaximum;
			currentGraphParameters.xMin = xMinimum;
			currentGraphParameters.xMax = xMaximum;
			currentGraphParameters.kMax = kMaximum;
			currentGraphParameters.zoomScale = zoomS;


			/*for (var i in ..<lImages.Count)
			{
				SafeDelete!(lImages[i]);
				SDL2.Image image = new Image();
				if (DrawUtils.CreateTexture(image, mSize, gEngineApp.mRenderer, .Streaming) case .Err(let err))
				{
					SDLError!(1);
				}
				lImages[i] = image;
			}*/
			/*mThreadEnabled = new bool[9];
			mThreadEnabled[0] = true;
			mThreadEnabled[1] = true;
			mThreadEnabled[3] = true;*/

			for (int32 i in 1 ..< 9)
				mRenderThreads.Add(new RenderThread(new Thread(new () => RenderImageByPixel(mRenderThreads[i - 1], currentGraphParameters, i)), false, mSize));

			mRenderThreads[0].Enabled = true;
			mRenderThreads[1].Enabled = true;
			mRenderThreads[3].Enabled = true;

			SafeMemberSet!(colourTable, new ColourTable(400));
		}

		public this(Vector2D chunkPos, Size2D size, int zoomS = 1)
		{
			mChunkPos = chunkPos;
			currentGraphParameters.yMin = chunkPos.mY;
			currentGraphParameters.yMax = (chunkPos.mY);
			currentGraphParameters.xMin = chunkPos.mX;
			currentGraphParameters.xMax = (chunkPos.mX);
			currentGraphParameters.zoomScale = zoomS;
			mSize = size;
		}

		public void SetGraphParameters(double yMinimum, double yMaximum, double xMinimum, double xMaximum, double kMaximum = -1, int zoomS = 1)
		{
			undoHistory.Add(currentGraphParameters);
			currentGraphParameters.yMin = yMinimum;
			currentGraphParameters.yMax = yMaximum;
			currentGraphParameters.xMin = xMinimum;
			currentGraphParameters.xMax = xMaximum;
			if (autoUpdateDepth && kMaximum == -1)
			{
				var absXMin = Math.Abs(xMinimum);
				var absXMax = Math.Abs(xMaximum);
				double xRange = 0;
				if (absXMin > absXMax)
					xRange = absXMin - absXMax;
				else
					xRange = absXMax - absXMin;

				double pow = Math.Pow(xRange, -0.163d);
				Logger.Debug(pow, xRange);
				var k = 400 * pow;
				currentGraphParameters.kMax = k;
			}
			else
				currentGraphParameters.kMax = kMaximum;
			currentGraphParameters.zoomScale = zoomS;
		}

		public ~this()
		{
			for (var thread in mRenderThreads)
			{
				thread.RequestAbort();
			}
			while (!RenderingDone)
			{
				SDL.Delay(10);// Wait for the threads to terminate before we free the resources.
			}
		}

		public void Draw()
		{
			Vector2D projectedPos = gGameApp.mCam.GetProjected(scope Vector2D(0, mSize.Height / 1000));
			defer delete projectedPos;
			var image = mCurrentImage;
			if (mAnimationThread.[Friend]mCurrentImage != null)
			{
				image = mAnimationThread.[Friend]mCurrentImage;
			}
			//mCurrentImage should always be a ref to the last Image that got completely rendered.
			if (image?.mTexture == null)
				return;
			gEngineApp.Draw(image, projectedPos.mX, projectedPos.mY, 0f, gGameApp.mCam.mSize);//mPos.mX, mPos.mY, mDrawAngle);
		}

		public void PreperRenderImages()
		{
			if (mAnimationThread.[Friend]animationRunning)
				return;
			for (var thread in mRenderThreads)
			{
				thread.RequestAbort();
			}
			var cnt = 0;
			while (!RenderingDone)
			{
				SDL.Delay(10);
				if (++cnt > 1000)
					break;
			}
			for (var thread in mRenderThreads)
			{
				thread.[Friend]_shouldAbort = false;
			}
			for (var i in ..<mRenderThreads.Count)
			{
				if (mRenderThreads[i].Enabled)
				{
					var t = mRenderThreads[i];
					while (t.IsAlive)
					{
						SDL.Delay(20);// Fail safe
					}
					t.StartThread();
				}
			}
		}

		public void RenderImageByPixel(RenderThread self, GraphParameters gp, int32 pixelStep, bool saveImage = true)
		{
			self.[Friend]_finishedRendering = false;
			var ret = GetRenderImage(self, gp, pixelStep);
			switch (ret)
			{
			case .Err(let err):
				self.[Friend]_shouldAbort = false;
				return;
			case .Ok(let retImage):
				if (saveImage)
					Volatile.Write<Image>(ref mCurrentImage, self.[Friend]_renderedImage);
			}
			self.[Friend]_renderTime += 1;
			self.[Friend]_finishedRendering = true;
			Logger.Debug(StackStringFormat!("{} : {}", pixelStep, TimeSpan(self.RenderTime)));
		}

		public Result<SDL2.Image> GetRenderImage(RenderThread self, GraphParameters gp, int32 pixelStep)
		{
			return GetRenderImage(self, self.[Friend]_renderedImage, gp, gp.yMin / gp.zoomScale + gp.yOffset,
				(gp.yMax) / gp.zoomScale + gp.yOffset,
				(gp.xMin) / gp.zoomScale + gp.xOffset,
				(gp.xMax) / gp.zoomScale + gp.xOffset,
				(int32)(gp.kMax + (gp.zoomScale / 10)), pixelStep);
		}

		public Result<SDL2.Image> GetRenderImage(RenderThread self, Image image, GraphParameters gp, double yMin, double yMax, double xMin, double xMax, int32 kMax, int32 pixelStep)
		{
			self.[Friend]_renderTime = 0;

			var err = SDL.LockTexture(image.mTexture, null, var data, var pitch);
			if (err != 0)
			{
				Logger.Debug(scope String(SDL.GetError()));
				self.[Friend]_renderTime = -1;
				SDL.UnlockTexture(image.mTexture);
				SDLError!(err);
				return .Err((void)"Thread terminated");
			}

			for (int i in ..<(int)(mSize.Width * mSize.Height))
			{
				((uint32*)data)[i] = (uint32)0;
			}


			int kLast = -1;
			SDL2.SDL.Color color;
			SDL2.SDL.Color colorLast = .();


			//var myPixelManager = GetScreenPixelManager(gp);
			ComplexPoint screenBottomLeft = ComplexPoint(xMin,
				yMin);
			ComplexPoint screenTopRight = ComplexPoint(xMax,
				yMax);
			var myPixelManager = new ScreenPixelManage(gGameApp.mRenderer, screenBottomLeft, screenTopRight);
			ComplexPoint xyStep = myPixelManager.GetDeltaMathsCoord(ComplexPoint(pixelStep, pixelStep));
			double min = 1d / Math.Pow((double)10, (double)15);
			xyStep.x = Math.Max(xyStep.x, min);
			xyStep.y = Math.Max(xyStep.y, min);
			SafeDeleteNullify!(myPixelManager);

			Stopwatch sw = scope Stopwatch();
			sw.Start();

			int yPix = (int)mSize.Height - 1;
			Logger.Debug("Y", (Math.Abs(yMin) + Math.Abs(yMax)) / xyStep.y);
			Logger.Debug("X", (Math.Abs(xMin) + Math.Abs(xMin)) / xyStep.x);
			for (double y = yMin; y < yMax; y += xyStep.y)
			{
				if (self.[Friend]_shouldAbort)
				{
					self.[Friend]_renderTime = -1;
					SDL.UnlockTexture(image.mTexture);
					return .Err((void)"Thread terminated");
				}

				int xPix = 0;

				for (double x = xMin; x < xMax; x += xyStep.x)
				{
					double cx = x;
					double cy = y;

					double zkx = 0;
					double zky = 0;

					int k = 0;
					double modulusSquared;
					repeat
					{
						double oldzkx = zkx;
						double oldzky = zky;

						zkx = oldzkx * oldzkx - oldzky * oldzky;
						zky = 2 * oldzkx * oldzky;
						zkx += cx;
						zky += cy;
						modulusSquared = zkx * zkx + zky * zky;

						k++;
					} while ((modulusSquared <= 4.0) && (k < kMax));

					if (k < kMax)
					{
						if (k == kLast)
						{
							color = colorLast;
						}
						else
						{
#if TRUE_COLOR
							double colourIndex = ((double)k) / kMax;
							double hue = Math.Pow(colourIndex, 0.25);

							color = ColourTable.ColorFromHSLA(hue, 0.9, 0.6);
#else
							color = colourTable.GetColour(k + k / 2);
							colorLast = color;
							kLast = k;
#endif
						}

						//SDL.SetRenderDrawColor(gEngineApp.mRenderer, color.r, color.g, color.b, color.a);
						//Logger.Debug(color.r, color.g, color.b, color.a);
						//SDL.RenderFillRect(gEngineApp.mRenderer, scope SDL.Rect((int32)xPix, (int32)yPix, xyPixelStep, -xyPixelStep));
						//SDL.PixelFormat* fmt = image.mSurface.format;
						/*((uint8*)data)[pitch * yPix + xPix + 0] = color.r;
						((uint8*)data)[pitch * yPix + xPix + 1] = color.g;//((uint32)color.r << fmt.rshift | (uint32)color.g << fmt.gshift | (uint32)color.b << fmt.bshift);
						((uint8*)data)[pitch * yPix + xPix + 2] = color.r;//((uint32)color.r << fmt.rshift | (uint32)color.g << fmt.gshift | (uint32)color.b << fmt.bshift);
						((uint8*)data)[pitch * yPix + xPix + 3] = color.a;//; ((uint32)color.r << fmt.rshift | (uint32)color.g << fmt.gshift | (uint32)color.b << fmt.bshift);*/
						//((uint32*)data)[image.mSurface.w * yPix + xPix] = ((uint32)color.r << fmt.rshift | (uint32)color.g << fmt.gshift | (uint32)color.b << fmt.bshift);

						if (pixelStep == 1)
						{
							// Pixel step is 1, set a single pixel.
							if ((xPix < image.mSurface.w) && (yPix >= 0))
							{
								SetPixel((uint32*)data, image, xPix, yPix, color);
							}
						} else
						{

							// Pixel step is > 1, set a square of pixels.
							/*SDL.Rect* drawRect = scope .((int32)xPix, (int32)yPix, xyPixelStep, xyPixelStep);
							SetPixels(drawRect, color);*/

							SetPixels((uint32*)data, image, xPix, yPix, pixelStep, pixelStep, color);
							/*for (int pX = 0; pX < xyPixelStep; pX++)
							{
								for (int pY = 0; pY < xyPixelStep; pY++)
								{
									if (((xPix + pX) < image.mSurface.w) && ((yPix - pY) >= 0))
									{
									}
								}
							}*/
						}
					}
					xPix += pixelStep;
					if (sw.ElapsedMicroseconds - self.[Friend]_renderTime >= 100000)
					{
						self.[Friend]_renderTime = sw.ElapsedMicroseconds;
					}
				}
				yPix -= pixelStep;
				/*if (yPix < 0)
				{
					sw.Stop();
					logCurrentTime(sw.ElapsedMicroseconds, pixelStep);

					SDL.UnlockTexture(image.mTexture);
					return .Ok(null);
				}*/
			}

			sw.Stop();
			SDL.UnlockTexture(image.mTexture);
			self.[Friend]_renderTime = sw.ElapsedMicroseconds;

			return .Ok(null);
		}

		public void Undo(bool undoK = false)
		{
			if (undoHistory.Count > 0)
			{
				var oldkMax = currentGraphParameters.kMax;
				currentGraphParameters = undoHistory.PopBack();
				if (undoK)
					currentGraphParameters.kMax = oldkMax;
			}
		}

		void SetPixels(uint32* data, Image image, int x, int y, int w, int h, SDL.Color color)
		{
			SDL.PixelFormat* fmt = image.mSurface.format;
			var color8888 = ((uint32)color.r << fmt.rshift | (uint32)color.g << fmt.gshift | (uint32)color.b << fmt.bshift) | (uint32)color.a;
			for (int iy = y; iy > y - w; iy--)
			{
				var indexY = (image.mSurface.w) * iy;
				if (indexY < 0 || iy >= image.mSurface.h)
					continue;
				for (int ix = x; ix < x + w; ix++)
				{
					if (ix < 0 || ix >= image.mSurface.w)
						continue;
					(data)[indexY + ix] = color8888;
				}
			}
		}

		public ScreenPixelManage GetScreenPixelManager()
		{
			ComplexPoint screenBottomLeft = ComplexPoint(currentGraphParameters.xMin / currentGraphParameters.zoomScale + currentGraphParameters.xOffset,
				currentGraphParameters.yMin / currentGraphParameters.zoomScale + currentGraphParameters.yOffset);
			ComplexPoint screenTopRight = ComplexPoint(currentGraphParameters.xMax / currentGraphParameters.zoomScale + currentGraphParameters.xOffset,
				currentGraphParameters.yMax / currentGraphParameters.zoomScale + currentGraphParameters.yOffset);
			return new ScreenPixelManage(gGameApp.mRenderer, screenBottomLeft, screenTopRight);
		}

		public ScreenPixelManage GetScreenPixelManager(GraphParameters gp)
		{
			ComplexPoint screenBottomLeft = ComplexPoint(gp.xMin / gp.zoomScale + gp.xOffset,
				gp.yMin / gp.zoomScale + gp.yOffset);
			ComplexPoint screenTopRight = ComplexPoint(gp.xMax / gp.zoomScale + gp.xOffset,
				gp.yMax / gp.zoomScale + gp.yOffset);
			return new ScreenPixelManage(gGameApp.mRenderer, screenBottomLeft, screenTopRight);
		}

		[Inline]
		void SetPixel(uint32* data, Image image, int x, int y, SDL.Color color)
		{
			SDL.PixelFormat* fmt = image.mSurface.format;
			(data)[(image.mSurface.w) * y + x] = ((uint32)color.r << fmt.rshift | (uint32)color.g << fmt.gshift | (uint32)color.b << fmt.bshift) | (uint32)color.a;
		}

		SDL.Color GetPixel(int x, int y)
		{
			SDL.PixelFormat* fmt = mCurrentImage.mSurface.format;
			uint8 bytes_per_pixel = fmt.bytesPerPixel;

			var pixel = mCurrentImage.mSurface.pixels;

			uint32* pixel_ptr = (uint32*)pixel + y * mCurrentImage.mSurface.pitch + x * bytes_per_pixel;

			/* Get Red component */
			uint32 temp = *(uint8*)pixel_ptr & fmt.Rmask;/* Isolate red component */
			temp = temp >> fmt.rshift;/* Shift it down to 8-bit */
			temp = temp << fmt.rloss;/* Expand to a full 8-bit number */
			uint8 red = (uint8)temp;

			/* Get Green component */
			temp = *(uint8*)pixel_ptr & fmt.Gmask;/* Isolate green component */
			temp = temp >> fmt.gshift;/* Shift it down to 8-bit */
			temp = temp << fmt.gloss;/* Expand to a full 8-bit number */
			uint8 green = (uint8)temp;

			/* Get Blue component */
			temp = *(uint8*)pixel_ptr & fmt.Bmask;/* Isolate blue component */
			temp = temp >> fmt.bshift;/* Shift it down to 8-bit */
			temp = temp << fmt.bloss;/* Expand to a full 8-bit number */
			uint8 blue = (uint8)temp;

			/* Get Alpha component */
			temp = *(uint8*)pixel_ptr & fmt.Amask;/* Isolate alpha component */
			temp = temp >> fmt.Ashift;/* Shift it down to 8-bit */
			temp = temp << fmt.Aloss;/* Expand to a full 8-bit number */
			uint8 alpha = (uint8)temp;

			return .(red, green, blue, alpha);
		}
	}

	namespace FractelOPOP.Entity.FractelChunk
	{
		struct Depth
		{
		}

		public class AnimationThread
		{
			RenderThread _renderThread = null ~ SafeDelete!(_);
			int animationIndex = 0;
			bool animationRunning = false;
			bool instantPresent = true;
			Image mCurrentImage = null ~ SafeDelete!(_);
			int presentDelay = -1;
			Stopwatch presentDelayer = new Stopwatch() ~ SafeDelete!(_);
			public List<GraphParameters> animationHistory = new List<GraphParameters>() ~ SafeDelete!(_);

			public bool IsAlive { get { return (bool)_renderThread?.IsAlive; } }
			SDL.Rect _targetRect = default;
			public this(FractelChunkMultiThread fc)
			{
				SafeMemberSet!(_renderThread, new RenderThread(new Thread(new () => fc.RenderImageByPixel(_renderThread, animationHistory[animationIndex++], 1, false)), false, fc.[Friend]mSize));
			}

			public void StopAnimation()
			{
				animationRunning = false;
				presentDelay = -1;
				_targetRect = .(0, 0, 0, 0);
				SafeMemberSet!(mCurrentImage, null);
			}

			public void AnimateHistory(FractelChunkMultiThread fc, int numThread = 1)
			{
				if (_renderThread != null)
				{
					if (!_renderThread.IsAlive)
					{
						if (presentDelay == -1)
						{
							presentDelay = _renderThread.RenderTime;

							_targetRect = .(0, 0, 0, 0);

							Logger.Debug(TimeSpan(presentDelay), presentDelay);

							presentDelayer.Restart();
							SafeMemberSet!(mCurrentImage, _renderThread.[Friend]_renderedImage);
							_renderThread.[Friend]_renderedImage = null;

							var basename = scope String();
							basename.AppendF(".\\png\\ani\\{}.png", animationIndex);
#if SAVING
							SDLError!(mCurrentImage.SaveTexture(basename, gGameApp.mRenderer));
#endif
							if ((animationIndex) < animationHistory.Count && animationIndex >= 1)
							{
								var next = animationHistory[animationIndex];
								var manager = fc.GetScreenPixelManager(animationHistory[animationIndex - 1]);
								defer { SafeDeleteNullify!(manager); }

								var minPos = manager.GetPixelCoord(v2d<double>(next.xMin, next.yMin));// bot left
								var maxPos = manager.GetPixelCoord(v2d<double>(next.xMax, next.yMax));//top right
								var width = (maxPos.x - minPos.x);
								var height = (minPos.y - maxPos.y);

								_targetRect.x = (int32)minPos.x;
								_targetRect.y = (int32)maxPos.y;

								_targetRect.w = (int32)width;
								_targetRect.h = (int32)height;
							}
						}
						if (instantPresent || presentDelayer.ElapsedMicroseconds > ((TimeSpan.TicksPerSecond / 2) - presentDelay))
						{
							if (animationIndex >= animationHistory.Count)
							{
								StopAnimation();
								return;
							}

							SafeMemberSet!(_renderThread, new RenderThread(new Thread(new () => fc.RenderImageByPixel(_renderThread, animationHistory[animationIndex++], 1, false)), false, fc.[Friend]mSize));
							_renderThread.Enabled = true;
							_renderThread.StartThread();
							presentDelayer.Stop();
							presentDelayer.Reset();
							presentDelay = -1;
						}
						else
						{
							_renderThread.[Friend]_renderTime = presentDelayer.ElapsedMicroseconds + presentDelay;
						}
					}
				}
			}

			public void StartAnimation(FractelChunkMultiThread fc)
			{
				if (animationHistory.Count == 0)
					return;
				if (animationRunning)
				{
					_renderThread.RequestAbort();
					while (_renderThread.IsAlive)
					{
						SDL.Delay(10);
					}
				}
				animationIndex = 0;
				SafeMemberSet!(_renderThread, new RenderThread(new Thread(new () => fc.RenderImageByPixel(_renderThread, animationHistory[animationIndex++], 1, false)), false, fc.[Friend]mSize));
				_renderThread.Enabled = true;
				_renderThread.StartThread();
				animationRunning = true;
			}

			public void CopyAnimation(List<GraphParameters> gp)
			{
				animationHistory.Clear();
				for (var para in gp)
				{
					animationHistory.Add(para);
				}
			}

			public void SmoothAnimation(float pct)
			{
				List<GraphParameters> buffer = scope List<GraphParameters>();
				for (int i in ..<animationHistory.Count)
				{
					buffer.Add(animationHistory[i]);
					if (i + 1 < animationHistory.Count)
					{
						var current = animationHistory[i];
						var next = animationHistory[i + 1];
						for (int x = 1; x < 100 / (pct * 100); x++)
						{
							GraphParameters gp = GraphParameters();
							if (pct * x >= 1f)
								break;
							gp.xMin = Math.Lerp(current.xMin, next.xMin, pct * x);
							gp.xMax = Math.Lerp(current.xMax, next.xMax, pct * x);
							gp.yMin = Math.Lerp(current.yMin, next.yMin, pct * x);
							gp.yMax = Math.Lerp(current.yMax, next.yMax, pct * x);
							gp.kMax = Math.Lerp(current.kMax, next.kMax, pct * x);
							buffer.Add(gp);
							if (x == 9)
							{
								NOP!();
							}
						}
					}
				}

				CopyAnimation(buffer);
			}
		}

		public class RenderThread
		{
			Thread _mainThread = null ~ SafeDelete!(_);
			bool _shouldAbort = false;
			bool _enabled = false;
			public bool Enabled { get { return _enabled; } set { _enabled = value; } }
			bool _savingImage = false;
			Image _renderedImage = null ~ SafeDelete!(_);
			Image _bufferImage = null ~ SafeDelete!(_);
			int64 _renderTime = -1;
			public int64 RenderTime { get { return _renderTime; } }
			bool _finishedRendering = false;
			public bool finishedRendering { get { return _finishedRendering; } }

			public bool IsAlive { get { return (bool)_mainThread?.IsAlive; } }

			public this(Thread mainThread, bool enabled, Size2D size)
			{
				_enabled = enabled;
				_mainThread = mainThread;

				SDL2.Image image = new Image();
				if (DrawUtils.CreateTexture(image, size, gEngineApp.mRenderer, .Streaming) case .Err(let err))
				{
					SDLError!(1);
				}
				_renderedImage = image;
			}

			public void StartThread()
			{
				_mainThread?.Start(false);
			}

			public void RequestAbort()
			{
				_shouldAbort = true;
			}
		}

		public struct GraphParameters
		{
			public double yMin = -2.0;// Default minimum Y for the set to render.
			public double yMax = 0.0;// Default maximum Y for the set to render.
			public double yOffset = 0.0;// Default maximum Y for the set to render.
			public double xMin = -2.0;// Default minimum X for the set to render.
			public double xMax = 1.0;// Default maximum X for the set to render.
			public double xOffset = 0;// Default maximum X for the set to render.
			public double kMax = 50;
			public double zoomScale = 1;// Default amount to zoom in by.
		}
	}
}
