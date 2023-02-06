using BasicEngine;
using System.Diagnostics;
using SDL2;
using BasicEngine.Debug;
using System;
using System.Collections;
using System.Threading;
using System.Threading.Tasks;
using MincedFractals.RenderThreads;
using MincedFractals.Math;
using MincedFractals.RenderThreads;
using BasicEngine.Math;



namespace MincedFractals.Entity
{
#if BigDouble
	public typealias Complex = BigDouble;
#else
	public typealias Complex = double;
#endif
	class FractalChunkMultiThread
	{
		private uint32 mDrawCycle = 0;
		private bool autoUpdateDepth = true;

		GraphParameters currentGraphParameters = .();
		List<GraphParameters> undoHistory = new List<GraphParameters>() ~ SafeDelete!(_);

		private ColourTable colourTable = null ~ SafeDelete!(_);// Colour table.

		volatile private Image mCurrentImage = null;//~ SafeDelete!(_);
		private Size2D mSize ~ SafeDelete!(_);

		public List<RenderThread> mRenderThreads = new List<RenderThread>() ~ DeleteContainerAndItems!(_);
		public AnimationThread mAnimationThread = null ~ SafeDelete!(_);
		public AnimationMultiThread mMultiAnimationThread = null ~ SafeDelete!(_);

		volatile private int[] pixelData = null ~ SafeDelete!(_);
		const int NumThreads = 4 * 4;
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

		public this(Size2D size, double yMinimum, double yMaximum, double xMinimum, double xMaximum, int32 kMaximum = -1, int zoomS = 1)
		{
			mSize = size;
			SetGraphParameters(yMinimum, yMaximum, xMinimum, xMaximum, kMaximum, zoomS);

			pixelData = new int[(int)(mSize.Width * mSize.Height)];
			ClearPixelBuffer();

			for (int32 i in 0 ..< NumThreads)
				mRenderThreads.Add(new RenderThread(new Thread(new () => RenderImageByPixel(mRenderThreads[i], currentGraphParameters, .(i + 1, i + 1), .(0), .(0))), false, mSize));

			mAnimationThread = new AnimationThread(this);
			mMultiAnimationThread = new AnimationMultiThread(this, 4);

			mRenderThreads[0].Enabled = true;
			mRenderThreads[1].Enabled = true;
			mRenderThreads[2].Enabled = true;
			mRenderThreads[3].Enabled = true;

			SafeMemberSet!(colourTable, new ColourTable(400));
		}

		public void SetGraphParameters(GraphParameters gp)
		{
			SetGraphParameters(gp.yMin, gp.yMax, gp.xMin, gp.xMax, gp.kMax, 1);
		}

		public void SetGraphParameters(double yMinimum, double yMaximum, double xMinimum, double xMaximum, double kMaximum = -1, int zoomS = 1)
		{
			if (currentGraphParameters.yMin != yMinimum ||
				currentGraphParameters.yMax != yMaximum ||
				currentGraphParameters.xMin != xMinimum ||
				currentGraphParameters.xMax != xMaximum)
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
			gEngineApp.Draw(image, projectedPos.mX, projectedPos.mY, 0f);//, gGameApp.mCam.mScale);//mPos.mX, mPos.mY, mDrawAngle);
		}

		public void StartRenderThreads()
		{
			if (mAnimationThread.[Friend]animationRunning)
				return;
			for (var thread in mRenderThreads)
			{
				thread.RequestAbort();
			}
			var cnt = 0;
			ClearPixelBuffer();
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

		public void RenderImageByPixel(RenderThread self, GraphParameters gp, v2d<int> pixelStep, v2d<int> offset, v2d<int> size, bool saveImage = true)
		{
			var size;

			self.[Friend]_finishedRendering = false;
			if (size.x == 0 && size.y == 0)
			{
				size.x = (int)mSize.mX;
				size.y = (int)mSize.mY;
			}
			var ret = GetRenderImage(self, gp, pixelStep, size, offset);
			switch (ret)
			{
			case .Err(let err):
				self.[Friend]_shouldAbort = false;
				return;
			case .Ok(let retImage):
				if (saveImage)
				{
					//self.RenderData();
					Volatile.Write<Image>(ref mCurrentImage, self.[Friend]_renderedImage);
				}
			}
			self.[Friend]_renderTime += 1;
			self.[Friend]_finishedRendering = true;
			Logger.Debug(StackStringFormat!("{} : {}", pixelStep.x, TimeSpan(self.RenderTime)));
		}

		public Result<SDL2.Image> GetRenderImage(RenderThread self, GraphParameters gp, v2d<int> pixelStep, v2d<int> size, v2d<int> offset)
		{
			self.[Friend]_renderTime = 0;

			var image = self.[Friend]_renderedImage;
			Complex yMax = Complex((gp.yMax) / gp.zoomScale + gp.yOffset);
			Complex yMin = Complex((gp.yMin) / gp.zoomScale + gp.yOffset);
			Complex xMax = Complex((gp.xMax) / gp.zoomScale + gp.xOffset);
			Complex xMin = Complex((gp.xMin) / gp.zoomScale + gp.xOffset);

			int32 kMax = (int32)gp.kMax;
			var err = SDL.LockTexture(image.mTexture, null, var data, var pitch);
			if (err != 0)
			{
				Logger.Debug(scope String(SDL.GetError()));
				self.[Friend]_renderTime = -1;
				SDL.UnlockTexture(image.mTexture);
				SDLError!(err);
				return .Err((void)"Thread terminated");
			}

			Internal.MemSet(data, 0, (int)(size.x * size.y) * image.mSurface.format.bytesPerPixel);
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
			ComplexPoint xyStep = myPixelManager.GetDeltaMathsCoord(ComplexPoint(pixelStep.x, pixelStep.y));
			//double min = 1d / Math.Pow((double)10, (double)10);
			/*xyStep.x = Math.Max(xyStep.x, min);
			xyStep.y = Math.Max(xyStep.y, min);*/
			SafeDeleteNullify!(myPixelManager);

			Stopwatch sw = scope Stopwatch();
			sw.Start();

			int yPix = (int)size.y - 1;
			//Logger.Debug("Y", (Math.Abs(yMin) + Math.Abs(yMax)) / xyStep.y);
			//Logger.Debug("X", (Math.Abs(xMin) + Math.Abs(xMax)) / xyStep.x);
			for (double y = yMin; y < yMax; y += xyStep.y)
			{
				if (yPix < offset.y)
					continue;

				int xPix = offset.x;

				for (double x = xMin; x < xMax; x += xyStep.x)
				{
					if (self.[Friend]_shouldAbort)
					{
						self.[Friend]_renderTime = -1;
						SDL.UnlockTexture(image.mTexture);
						return .Err((void)"Thread terminated");
					}
					if (xPix >= image.mSurface.w || xPix > size.x)
						continue;

					Complex cx = Complex(x);
					Complex cy = Complex(y);

					Complex zkx = .(0);
					Complex zky = .(0);

					int k = 0;
					double modulusSquared;
					if (pixelData[(int)(yPix * image.mSurface.w + xPix)] != -1)
					{
						k = pixelData[(int)(yPix * image.mSurface.w + xPix)];
					} else
					{
						repeat
						{
							Complex oldzkx = zkx;
							Complex oldzky = zky;

							zkx = oldzkx * oldzkx - oldzky * oldzky;
#if BigDouble
							zky = (oldzkx.mul2()) * oldzky;
#else
							zky = 2 * oldzkx * oldzky;
#endif
							zkx += cx;
							zky += cy;
							modulusSquared = zkx * zkx + zky * zky;

							k++;
						} while ((modulusSquared <= 4.0) && (k < kMax));
					}

					if (k < kMax)
					{
						pixelData[(int)(yPix * image.mSurface.w + xPix)] = k;
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
							color = ColourTable.ColorFromHSLA(hue, 0.9, 0.6);
#else
							color = colourTable.GetColour(k * 2);
							colorLast = color;
							kLast = k;
#endif
						}

						if (pixelStep.x == 1 && pixelStep.y == 1)
						{
							// Pixel step is 1, set a single pixel.
							SetPixel((uint32*)data, image, xPix, yPix, color);
						} else
						{
							SetPixels((uint32*)data, image, xPix, yPix, pixelStep.x, pixelStep.y, color);
						}
					}
					xPix += pixelStep.x;
					if (sw.ElapsedMicroseconds - self.[Friend]_renderTime >= 100000)
					{
						self.[Friend]_renderTime = sw.ElapsedMicroseconds;
					}
				}
				yPix -= pixelStep.y;
				if (yPix < 0)
				{
					sw.Stop();
					self.[Friend]_renderTime = sw.ElapsedMicroseconds;

					SDL.UnlockTexture(image.mTexture);
					return .Ok(null);
				}
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

		public void ClearPixelBuffer()
		{
			for (int i in ..<(int)(mSize.Width * mSize.Height))
			{
				pixelData[i] = -1;
			}
		}
	}
}
