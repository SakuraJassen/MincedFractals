using BasicEngine;
using System.Diagnostics;
using SDL2;
using BasicEngine.Debug;
using System;
using System.Collections;
using System.Threading;
using System.Threading.Tasks;

namespace FractelOPOP.Entity
{
	class FractelChunkMultiThread
	{
		Vector2D mChunkPos = null ~ SafeDelete!(_);

		private uint32 mDrawCycle = 0;

		private double yMin = -2.0;// Default minimum Y for the set to render.
		private double yMax = 0.0;// Default maximum Y for the set to render.
		public double yOffset = 0.0;// Default maximum Y for the set to render.
		private double xMin = -2.0;// Default minimum X for the set to render.
		private double xMax = 1.0;// Default maximum X for the set to render.
		public double xOffset = 0;// Default maximum X for the set to render.
		private int32 kMax = 50;
		private int32 xyPixelStep = 4;
		private int32 numColours = 85;// Default number of colours to use in colour table.
		private float zoomScale = 1;// Default amount to zoom in by.

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

		public this(Size2D size, double yMinimum, double yMaximum, double xMinimum, double xMaximum, int32 pixelStep = 1, int32 kMaximum = 200, int zoomS = 1)
		{
			mSize = size;
			yMin = yMinimum;
			yMax = yMaximum;
			xMin = xMinimum;
			xMax = xMaximum;
			kMax = kMaximum;
			xyPixelStep = pixelStep;
			zoomScale = zoomS;


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

			mRenderThreads.Add(new Thread(new () => RenderImageOne()));
			mRenderThreads.Add(new Thread(new () => RenderImageTwo()));
			mRenderThreads.Add(new Thread(new () => RenderImageThree()));
			mRenderThreads.Add(new Thread(new () => RenderImageFour()));
			mRenderThreads.Add(new Thread(new () => RenderImage5()));

			mThreadEnabled = new bool[8];
			mThreadEnabled[0] = true;
			mThreadEnabled[2] = false;
			mThreadEnabled[4] = false;

			SafeMemberSet!(colourTable, new ColourTable(10000, 10000));
		}

		public this(Vector2D chunkPos, Size2D size, int pixelStep = 1, int zoomS = 1)
		{
			mChunkPos = chunkPos;
			yMin = chunkPos.mY;
			yMax = (chunkPos.mY + pixelStep);
			xMin = chunkPos.mX;
			xMax = (chunkPos.mX + pixelStep);
			zoomScale = zoomS;
			xyPixelStep = (int32)pixelStep;
			mSize = size;
		}

		public void Draw()
		{
			Vector2D projectedPos = gGameApp.mCam.GetProjected(scope Vector2D(0, mSize.Height / 1000));
			defer delete projectedPos;
			Image drawImage = Volatile.Read<Image>(ref mCurrentImage);
			for (var i in ..<mRenderThreads.Count)
			{
				if (mRenderThreads[i].IsAlive == false)
				{
					mCurrentImage = Volatile.Read<Image>(ref lImages[i + 1]);
					break;//Volatile.Read<Image>(ref mCurrentImage);
				}
			}

			if (mCurrentImage?.mTexture == null)
				return;
			gEngineApp.Draw(mCurrentImage, projectedPos.mX, projectedPos.mY, 0f, gGameApp.mCam.mSize);//mPos.mX, mPos.mY, mDrawAngle);
		}

		bool deletingOldImages = false;
		public void PreperRenderImages()
		{
			List<bool> lbool = scope List<bool>();

			for (var i in ..<mThreadEnabled.Count)
			{
				lbool.Add(mThreadEnabled[i]);
				mThreadEnabled[i] = false;
			}
			while (!RenderingDone)
			{
				SDL.Delay(10);
			}
			for (var i in ..<lbool.Count)
			{
				mThreadEnabled[i] = lbool[i];
			}
			deletingOldImages = true;
			SDL.Delay(200);
			//var images = Volatile.Read<Image[]>(ref lImages);

			/*for (var i in ..<images.Count)
			{
				SafeDelete!(images[i]);
				images[i] = null;
				SDL2.Image image = new Image();
				if (DrawUtils.CreateTexture(image, mSize, gEngineApp.mRenderer, .Streaming) case .Err(let err))
				{
					SDLError!(1);
				}
				images[i] = image;
			}*/

			deletingOldImages = false;

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
			{
				/*for (var i in ..<mRenderThreads.Count)
				{
					DeleteAndNullify!(mRenderThreads[i]);
				}
				mRenderThreads.Clear();

				mRenderThreads.Add(new Thread(new () => RenderImageOne()));
				mRenderThreads.Add(new Thread(new () => RenderImageThree()));
				mRenderThreads.Add(new Thread(new () => RenderImage5()));*/
			}
		}

		public void RenderImageByPixel(int32 pixelStep)
		{
			var images = Volatile.Read<Image>(ref lImages[pixelStep]);
			var ret = GetRenderImage(images, yMin / zoomScale + yOffset, (yMax) / zoomScale + yOffset, (xMin) / zoomScale + xOffset, (xMax) / zoomScale + xOffset, (int32)(kMax + (zoomScale / 10)), pixelStep);
			switch (ret)
			{
			case .Err(let err):
				return;
			case .Ok(let retImage):
				int cnt = 0;
				/*while (savingImage || deletingOldImages)
				{
					SDL.Delay(1);
					if (++cnt > 300)
					{
						break;
					}
				}
				savingImage = true;
				var img = Volatile.Read<Image>(ref mCurrentImage);
				var imgList = Volatile.Read<Image[]>(ref lImages);
				imgList.Add(img);
				Volatile.Write<Image>(ref mCurrentImage, ret);
				savingImage = false;*/
			}
		}

		public void RenderImageOne()
		{
			RenderImageByPixel(1);
		}
		public void RenderImageTwo()
		{
			RenderImageByPixel(2);
		}
		public void RenderImageThree()
		{
			RenderImageByPixel(3);
		}
		public void RenderImageFour()
		{
			RenderImageByPixel(4);
		}

		public void RenderImage5()
		{
			RenderImageByPixel(5);
		}

		public void RenderImage6()
		{
			RenderImageByPixel(6);
		}

		public void RenderImage()
		{
			Debug.FatalError("Memory Leak!");
			SDL2.Image image = new Image();
			if (DrawUtils.CreateTexture(image, mSize, gEngineApp.mRenderer, .Streaming) case .Err(let err))
			{
				SDLError!(1);
			}
			var ret = GetRenderImage(image, yMin / zoomScale + yOffset, (yMax) / zoomScale + yOffset, (xMin) / zoomScale + xOffset, (xMax) / zoomScale + xOffset, (int32)(kMax + zoomScale), xyPixelStep);

			Image img = Volatile.Read<Image>(ref mCurrentImage);
			if (img != null)
				delete img;
			Volatile.Write<Image>(ref mCurrentImage, ret);
			Volatile.Write<Image>(ref lImages[0], ret);

			//SafeMemberSet!(mImage, ret);
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

			ComplexPoint screenBottomLeft = ComplexPoint(xMin, yMin);
			ComplexPoint screenTopRight = ComplexPoint(xMax, yMax);

			var myPixelManager = scope ScreenPixelManage(gGameApp.mRenderer, screenBottomLeft, screenTopRight);

			ComplexPoint xyStep = myPixelManager.GetDeltaMathsCoord(ComplexPoint(pixelStep, pixelStep));

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
						if (k >= kMax)
						{
							NOP!();
						}
					} while ((modulusSquared <= 4.0) && (k < kMax));

					if (k < kMax)
					{
						if (k == kLast)
						{
							color = colorLast;
						}
						else
						{
							/*double colourIndex = ((double)k) / kMax;
							double hue = Math.Pow(colourIndex, 0.25);

							color = ColourTable.ColorFromHSLA(hue, 0.9, 0.6);*/

							color = colourTable.GetColour(k);
							colorLast = color;
							kLast = k;
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
				if (yPix < 0)
				{
					sw.Stop();
					logCurrentTime(sw.ElapsedMicroseconds, pixelStep);

					SDL.UnlockTexture(image.mTexture);
					return .Ok(image);
				}
				if (sw.ElapsedMicroseconds - getCurrentTime(pixelStep) >= 1000000)
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
			Logger.Debug(StackStringFormat!("{} : {}", pixelStep, TimeSpan(renderingTime)));
		}

		int64 getCurrentTime(int pixelStep)
		{
			return Volatile.Read<int64>(ref lastRenderingTime[pixelStep]);
		}

		void SetPixels(uint32* data, Image image, int x, int y, int w, int h, SDL.Color color)
		{
			SDL.PixelFormat* fmt = image.mSurface.format;
			var color8888 = ((uint32)color.r << fmt.rshift | (uint32)color.g << fmt.gshift | (uint32)color.b << fmt.bshift) | (uint32)color.a;
			for (int iy = y; iy > y - w; iy--)
			{
				var indexY = (image.mSurface.w) * iy;
				if (indexY < 0)
					continue;
				for (int ix = x; ix < x + w; ix++)
				{
					if (ix < 0)
						continue;
					(data)[indexY + ix] = color8888;
				}
			}
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
}
