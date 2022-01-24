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
	class FractelChunk
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

		private Image mImage ~ SafeDelete!(_);
		private List<Image> lImages = new List<Image>() ~ DeleteContainerAndItems!(_);
		private Size2D mSize ~ SafeDelete!(_);

		public Thread mRenderThread = new Thread(new () => RenderImage()) ~ SafeDelete!(_);

		private bool savingImage = false;
		private int64 lastRenderingTime = -1;
		public int64 LastRenderingTime { get { return Volatile.Read<int64>(ref lastRenderingTime); } }

		public bool RenderingDone
		{
			get
			{
				return !mRenderThread.IsAlive;
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
			Vector2D projectedPos = gGameApp.mCam.GetProjected(scope Vector2D(0, 0));
			defer delete projectedPos;

			Image drawImage = Volatile.Read<Image>(ref mImage);
			if (drawImage?.mTexture == null)
				return;
			gEngineApp.Draw(drawImage, projectedPos.mX, projectedPos.mY - mSize.Height / 2);//mPos.mX, mPos.mY, mDrawAngle);
		}

		public void PreperRenderImages()
		{
			if (RenderingDone)
				mRenderThread.Start(false);
		}

		public void RenderImageByPixel(int32 pixelStep)
		{
			var ret = GetRenderImage(yMin / zoomScale + yOffset, (yMax) / zoomScale + yOffset, (xMin) / zoomScale + xOffset, (xMax) / zoomScale + xOffset, kMax, pixelStep);
			while (savingImage)
			{
				SDL.Delay(1);
			}
			savingImage = true;
			//var img = Volatile.Read<Image>(ref lImages[pixelStep - 1]);
			if (lImages[pixelStep - 1] != null)
				delete lImages[pixelStep - 1];
			Volatile.Write<Image>(ref lImages[pixelStep - 1], ret);
			Volatile.Write<Image>(ref mImage, ret);
			savingImage = false;

			//SafeMemberSet!(mImage, ret);
			//SafeMemberSet!(mImage, ret);
		}

		public void RenderImage()
		{
			var ret = GetRenderImage(yMin / zoomScale + yOffset, (yMax) / zoomScale + yOffset, (xMin) / zoomScale + xOffset, (xMax) / zoomScale + xOffset, (int32)(kMax + zoomScale), xyPixelStep);
			while (savingImage)
			{
				SDL.Delay(10);
			}
			savingImage = true;
			//Image img = Volatile.Read<Image>(ref mImage);
			if (mImage != null)
				delete mImage;
			//Volatile.Write<Image>(ref mImage, ret);
			mImage = ret;
			savingImage = false;

			//SafeMemberSet!(mImage, ret);
		}

		/*public void RenderImageSingleThread()
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
		}*/

		public SDL2.Image GetRenderImage(double yMin, double yMax, double xMin, double xMax, int32 kMax, int32 xyPixelStep)
		{
			numColours = kMax;
			/*if ((colourTable == null) || (kMax != colourTable.kMax) || (numColours != colourTable.nColour))
			{
				SafeMemberSet!(colourTable, new ColourTable(numColours, kMax));
			}*/

			SDL2.Image image = new Image();
			DrawUtils.CreateTexture(image, mSize, gEngineApp.mRenderer, .Streaming);

			var err = SDL.LockTexture(image.mTexture, null, var data, var pitch);
			if (err != 0)
			{
				Logger.Debug(scope String(SDL.GetError()));
			}

			int kLast = -1;
			SDL2.SDL.Color color;
			SDL2.SDL.Color colorLast = .();

			ComplexPoint screenBottomLeft = ComplexPoint(xMin, yMin);
			ComplexPoint screenTopRight = ComplexPoint(xMax, yMax);

			var myPixelManager = scope ScreenPixelManage(gGameApp.mRenderer, screenBottomLeft, screenTopRight);

			ComplexPoint pixelStep = ComplexPoint(xyPixelStep, xyPixelStep);
			ComplexPoint xyStep = myPixelManager.GetDeltaMathsCoord(pixelStep);

			Stopwatch sw = scope Stopwatch();
			sw.Start();

			int yPix = (int)mSize.Height - 1;
			for (double y = yMin; y < yMax; y += xyStep.y)
			{
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
						double zkx2 = (double)oldzkx * oldzkx;
						double zky2 = (double)oldzky * oldzky;

						zkx = zkx2 - zky2;
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
							double colourIndex = ((double)k) / kMax;
							double hue = Math.Pow(colourIndex, 0.25);

							color = ColourTable.ColorFromHSLA(hue, 0.9, 0.6);

							//color = colourTable.GetColour(k);
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

						if (xyPixelStep == 1)
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

							SetPixels((uint32*)data, image, xPix, yPix, xyPixelStep, xyPixelStep, color);
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
					xPix += xyPixelStep;
				}
				yPix -= xyPixelStep;
#if DEBUG
				if(yPix <= 0)
				{
					Logger.Debug("We alive");
				}
#endif
			}

			sw.Stop();
			int64 renderingTime = sw.ElapsedMicroseconds;
			Volatile.Write<int64>(ref lastRenderingTime, renderingTime);
			Logger.Debug(TimeSpan(renderingTime));
			SDL.UnlockTexture(image.mTexture);
			return image;
		}

		void SetPixels(uint32* data, Image image, int x, int y, int w, int h, SDL.Color color)
		{
			SDL.PixelFormat* fmt = image.mSurface.format;
			var color8888 = ((uint32)color.r << fmt.rshift | (uint32)color.g << fmt.gshift | (uint32)color.b << fmt.bshift) | (uint32)color.a;
			for (int iy = y; iy > y - w; iy--)
			{
				var indexY = (image.mSurface.w) * iy;
				for (int ix = x; ix < x + w; ix++)
				{
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
			SDL.PixelFormat* fmt = mImage.mSurface.format;
			uint8 bytes_per_pixel = fmt.bytesPerPixel;

			var pixel = mImage.mSurface.pixels;

			uint32* pixel_ptr = (uint32*)pixel + y * mImage.mSurface.pitch + x * bytes_per_pixel;

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
