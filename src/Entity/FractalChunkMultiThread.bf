using BasicEngine;
using System.Diagnostics;
using SDL2;
using BasicEngine.Debug;
using System;
using System.Collections;
using System.Threading;
using System.Threading.Tasks;
using MincedFractals.Entity.FractalChunk;

namespace MincedFractals.Entity
{
	class FractalChunkMultiThread
	{
		Vector2D mChunkPos = null ~ SafeDelete!(_);

		private uint32 mDrawCycle = 0;
		private bool autoUpdateDepth = true;

		GraphParameters currentGraphParameters = .();
		List<GraphParameters> undoHistory = new List<GraphParameters>() ~ SafeDelete!(_);

		private ColourTable colourTable = null ~ SafeDelete!(_);// Colour table.

		volatile private Image mCurrentImage = null;//~ SafeDelete!(_);
		private Size2D mSize ~ SafeDelete!(_);

		public List<RenderThread> mRenderThreads = new List<RenderThread>() ~ DeleteContainerAndItems!(_);
		public AnimationThread mAnimationThread = null ~ SafeDelete!(_);

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


			for (int32 i in 1 ..< 9)
				mRenderThreads.Add(new RenderThread(new Thread(new () => RenderImageByPixel(mRenderThreads[i - 1], currentGraphParameters, i)), false, mSize));

			mAnimationThread = new AnimationThread(this);

			mRenderThreads[0].Enabled = true;
			mRenderThreads[1].Enabled = true;
			mRenderThreads[3].Enabled = true;

			SafeMemberSet!(colourTable, new ColourTable(400));
		}

		public void SetGraphParameters(GraphParameters gp)
		{
			SetGraphParameters(gp.yMin, gp.yMax, gp.xMin, gp.xMax, gp.kMax, 1);
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
			gEngineApp.Draw(image, projectedPos.mX, projectedPos.mY, 0f, gGameApp.mCam.mScale);//mPos.mX, mPos.mY, mDrawAngle);
		}

		public void StartRenderThreads()
		{
			if (mAnimationThread.[Friend]animationRunning)
				return;
			gGameApp.mCam.Reset();
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
				{
//					self.SmoothImage(0.5f);
					Volatile.Write<Image>(ref mCurrentImage, self.[Friend]_renderedImage);
				}
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

			Internal.MemSet(data, 0, (int)(mSize.Width * mSize.Height) * image.mSurface.format.bytesPerPixel);
			/*for (int i in ..<(int)(mSize.Width * mSize.Height))
			{
				((uint32*)data)[i] = (uint32)0;
			}*/

			int kLast = -1;
			SDL2.SDL.Color color;
			SDL2.SDL.Color colorLast = .();

			ComplexPoint screenBottomLeft = ComplexPoint(xMin, yMin);
			ComplexPoint screenTopRight = ComplexPoint(xMax, yMax);
			var myPixelManager = new ScreenPixelManage(screenBottomLeft, screenTopRight, mSize);
			ComplexPoint xyStep = myPixelManager.GetDeltaMathsCoord(ComplexPoint(pixelStep, pixelStep));
			double min = 1d / Math.Pow((double)10, (double)14);
			/*xyStep.x = Math.Max(xyStep.x, min);
			xyStep.y = Math.Max(xyStep.y, min);*/
			SafeDeleteNullify!(myPixelManager);

			Stopwatch sw = scope Stopwatch();
			sw.Start();

			int yPix = (int)mSize.Height - 1;
			Logger.Debug("Y", (Math.Abs(yMin) + Math.Abs(yMax)) / xyStep.y);
			Logger.Debug("X", (Math.Abs(xMin) + Math.Abs(xMax)) / xyStep.x);
			for (double y = yMin; y < yMax; y += xyStep.y)
			{
				if (yPix < 0)
					continue;
				if (self.[Friend]_shouldAbort)
				{
					self.[Friend]_renderTime = -1;
					SDL.UnlockTexture(image.mTexture);
					return .Err((void)"Thread terminated");
				}

				int xPix = 0;

				for (double x = xMin; x < xMax; x += xyStep.x)
				{
					if (xPix >= image.mSurface.w)
						continue;

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
//#define TRUE_COLOR
#if TRUE_COLOR
							double colourIndex = ((double)k) / kMax;
							double hue = Math.Pow(colourIndex, 0.25);
							color = ColourTable.ColorFromHSLA(0.5, 0.9, colourIndex * 0.6);
#else
							color = colourTable.GetColour(k * 2);
							colorLast = color;
							kLast = k;
#endif
						}

						if (pixelStep == 1)
						{
							// Pixel step is 1, set a single pixel.
							SetPixel((uint32*)data, image, xPix, yPix, color);
						} else
						{
							SetPixels((uint32*)data, image, xPix, yPix, pixelStep, pixelStep, color);
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
			return new ScreenPixelManage(screenBottomLeft, screenTopRight, mSize);
		}

		public ScreenPixelManage GetScreenPixelManager(GraphParameters gp)
		{
			ComplexPoint screenBottomLeft = ComplexPoint(gp.xMin / gp.zoomScale + gp.xOffset,
				gp.yMin / gp.zoomScale + gp.yOffset);
			ComplexPoint screenTopRight = ComplexPoint(gp.xMax / gp.zoomScale + gp.xOffset,
				gp.yMax / gp.zoomScale + gp.yOffset);
			return new ScreenPixelManage(screenBottomLeft, screenTopRight, mSize);
		}

		[Inline, DisableChecks]
		void SetPixel(uint32* data, Image image, int x, int y, SDL.Color color)
		{
			SDL.PixelFormat* fmt = image.mSurface.format;

			(data)[(image.mSurface.w) * y + x] = ((uint32)color.r << fmt.rshift | (uint32)color.g << fmt.gshift | (uint32)color.b << fmt.bshift) | (uint32)color.a;
		}

		SDL.Color GetPixel(int x, int y)
		{
			Debug.FatalError("broken");
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
}
