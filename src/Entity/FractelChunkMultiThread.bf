using BasicEngine;
using System.Diagnostics;
using SDL2;
using BasicEngine.Debug;
using System;
using System.Collections;
using System.Threading;
using System.Threading.Tasks;
using FractelOPOP.Entity.FractelOPOP.Entity.FractelChunk;

namespace FractelOPOP.Entity
{
	class FractelChunkMultiThread
	{
		Vector2D mChunkPos = null ~ SafeDelete!(_);

		private uint32 mDrawCycle = 0;

		GraphParameters currentGraphParameters = .();
		List<GraphParameters> undoHistory = new List<GraphParameters>() ~ SafeDelete!(_);

		private ColourTable colourTable = null ~ SafeDelete!(_);// Colour table.

		volatile private Image mCurrentImage = null;//~ SafeDelete!(_);
		volatile private Image[] lImages = new Image[16]() ~ DeleteContainerAndItems!(_);
		private Size2D mSize ~ SafeDelete!(_);

		public List<Thread> mRenderThreads = new List<Thread>() ~ DeleteContainerAndItems!(_);
		volatile public bool[] mThreadEnabled = null ~ SafeDelete!(_);
		volatile private bool savingImage = false;
		volatile private int64[] lastRenderingTime = new int64[16]() ~ SafeDelete!(_);
		public int64[] LastRenderingTimes { get { return Volatile.Read<int64[]>(ref lastRenderingTime); } }

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


			for (var i in ..<lImages.Count)
			{
				SafeDelete!(lImages[i]);
				SDL2.Image image = new Image();
				if (DrawUtils.CreateTexture(image, mSize, gEngineApp.mRenderer, .Streaming) case .Err(let err))
				{
					SDLError!(1);
				}
				lImages[i] = image;
			}
			mThreadEnabled = new bool[9];
			mThreadEnabled[0] = true;
			mThreadEnabled[1] = true;
			mThreadEnabled[3] = true;

			for (int32 i in ..<mThreadEnabled.Count)
				mRenderThreads.Add(new Thread(new () => RenderImageByPixel(i + 1)));

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

		public void SetMembers(double yMinimum, double yMaximum, double xMinimum, double xMaximum, double kMaximum = 700, int zoomS = 1)
		{
			undoHistory.Add(currentGraphParameters);
			currentGraphParameters.yMin = yMinimum;
			currentGraphParameters.yMax = yMaximum;
			currentGraphParameters.xMin = xMinimum;
			currentGraphParameters.xMax = xMaximum;
			currentGraphParameters.kMax = kMaximum;
			currentGraphParameters.zoomScale = zoomS;
		}

		public ~this()
		{
			for (var i in ..<mThreadEnabled.Count)
			{
				mThreadEnabled[i] = false;
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

			//mCurrentImage should always be a ref to the last Image that got completely rendered.
			if (mCurrentImage?.mTexture == null)
				return;
			gEngineApp.Draw(mCurrentImage, projectedPos.mX, projectedPos.mY, 0f, gGameApp.mCam.mSize);//mPos.mX, mPos.mY, mDrawAngle);
		}

		public void PreperRenderImages()
		{
			List<bool> lbool = scope List<bool>();

			for (var i in ..<mThreadEnabled.Count)
			{
				lbool.Add(mThreadEnabled[i]);
				mThreadEnabled[i] = false;
			}
			var cnt = 0;
			while (!RenderingDone)
			{
				SDL.Delay(10);
				if (++cnt > 1000)
					break;
			}
			for (var i in ..<lbool.Count)
			{
				mThreadEnabled[i] = lbool[i];
			}
			for (var i in ..<mRenderThreads.Count)
			{
				if (mThreadEnabled[i])
				{
					var t = mRenderThreads[i];
					t.Interrupt();
					while (t.IsAlive)
					{
						SDL.Delay(20);
					}
					t.Start(false);
				}
			}
		}

		public void RenderImageByPixel(int32 pixelStep)
		{
			var images = Volatile.Read<Image>(ref lImages[pixelStep]);
			var ret = GetRenderImage(images, currentGraphParameters.yMin / currentGraphParameters.zoomScale + currentGraphParameters.yOffset,
				(currentGraphParameters.yMax) / currentGraphParameters.zoomScale + currentGraphParameters.yOffset,
				(currentGraphParameters.xMin) / currentGraphParameters.zoomScale + currentGraphParameters.xOffset,
				(currentGraphParameters.xMax) / currentGraphParameters.zoomScale + currentGraphParameters.xOffset,
				(int32)(currentGraphParameters.kMax + (currentGraphParameters.zoomScale / 10)), pixelStep);
			switch (ret)
			{
			case .Err(let err):
				return;
			case .Ok(let retImage):
				Volatile.Write<Image>(ref mCurrentImage, images);
			}
			logCurrentTime(LastRenderingTimes[pixelStep] + 1, pixelStep);
			Logger.Debug(StackStringFormat!("{} : {}", pixelStep, TimeSpan(LastRenderingTimes[pixelStep])));
		}



		public Result<SDL2.Image> GetRenderImage(Image image, double yMin, double yMax, double xMin, double xMax, int32 kMax, int32 pixelStep)
		{
			Volatile.Write<int64>(ref lastRenderingTime[pixelStep], 0);

			var err = SDL.LockTexture(image.mTexture, null, var data, var pitch);
			if (err != 0)
			{
				Logger.Debug(scope String(SDL.GetError()));
				logCurrentTime(-1, pixelStep);
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


			var myPixelManager = GetScreenPixelManager();
			ComplexPoint xyStep = myPixelManager.GetDeltaMathsCoord(ComplexPoint(pixelStep, pixelStep));
			double min = 1d / Math.Pow((double)10, (double)15);
			xyStep.x = Math.Max(xyStep.x, min);
			xyStep.y = Math.Max(xyStep.y, min);
			SafeDeleteNullify!(myPixelManager);

			Stopwatch sw = scope Stopwatch();
			sw.Start();

			int yPix = (int)mSize.Height - 1;
			for (double y = yMin; y < yMax; y += xyStep.y)
			{
				if (!mThreadEnabled[pixelStep - 1])
				{
					logCurrentTime(-1, pixelStep);
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
				}
				yPix -= pixelStep;
				/*if (yPix < 0)
				{
					sw.Stop();
					logCurrentTime(sw.ElapsedMicroseconds, pixelStep);

					SDL.UnlockTexture(image.mTexture);
					return .Ok(null);
				}*/
				if (sw.ElapsedMicroseconds - getCurrentTime(pixelStep) >= 100000)
				{
					logCurrentTime(sw.ElapsedMicroseconds, pixelStep);
				}
			}

			sw.Stop();
			logCurrentTime(sw.ElapsedMicroseconds, pixelStep);

			SDL.UnlockTexture(image.mTexture);
			return .Ok(null);
		}

		void logCurrentTime(int64 renderingTime, int pixelStep)
		{
			Volatile.Write<int64>(ref lastRenderingTime[pixelStep], renderingTime);
		}

		int64 getCurrentTime(int pixelStep)
		{
			return Volatile.Read<int64>(ref lastRenderingTime[pixelStep]);
		}

		public void Undo()
		{
			if (undoHistory.Count > 0)
			{
				var oldkMax = currentGraphParameters.kMax;
				currentGraphParameters = undoHistory.PopBack();
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
