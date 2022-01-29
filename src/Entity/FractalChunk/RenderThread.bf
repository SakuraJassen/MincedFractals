using SDL2;
using System.Threading;
using BasicEngine;
using System;
using BasicEngine.Debug;
namespace MincedFractals.Entity.FractalChunk
{
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

		public void SmoothImage(float bias)
		{
			var renderer = gGameApp.mRenderer;
			SDL.Texture* target = SDL.GetRenderTarget(renderer);
			SDL.SetRenderTarget(renderer, _renderedImage.mTexture);
			SDL.QueryTexture(_renderedImage.mTexture, var format, var access, var width, var height);
			SDL.RenderCopy(renderer, _renderedImage.mTexture, null, null);
			_renderedImage.mSurface = SDL.CreateRGBSurfaceWithFormat(0, width, height, 32, format);
			SDL.RenderReadPixels(renderer, null, _renderedImage.mSurface.format.format, _renderedImage.mSurface.pixels, _renderedImage.mSurface.pitch);
			var err = SDL.LockTexture(_renderedImage.mTexture, null, var data, var pitch);
			if (err != 0)
			{
				Logger.Debug(scope String(SDL.GetError()));
				SDL.UnlockTexture(_renderedImage.mTexture);
				SDLError!(err);
				return;
			}
			Internal.MemSet(data, 0, (int)(width * height) * _renderedImage.mSurface.format.bytesPerPixel);

			for (var x = 0; x < width; x++)
			{
				for (var y = 0; y < height; y++)
				{
					SDL.Color col = DrawUtils.GetPixel((uint32*)_renderedImage.mSurface.pixels, _renderedImage, x, y);

					/*for (int xOffset = -1; xOffset < 2; xOffset++)
					{
						for (int yOffset = -1; yOffset < 2; yOffset++)
						{
							var yAdjusted = y + yOffset;
							if (yAdjusted < 0 || yAdjusted >= height)
								continue;
							var xAdjusted = x + xOffset;
							if (xAdjusted < 0 || xAdjusted >= width)
								continue;
							if (!(yOffset == 0 && xOffset == 0))
							{
								var neighbourColor = DrawUtils.GetPixel((uint32*)_renderedImage.mSurface.pixels,
					_renderedImage, xAdjusted, yAdjusted); col.r = (uint8)Math.Lerp(col.r, neighbourColor.r, bias); 
					col.g = (uint8)Math.Lerp(col.g, neighbourColor.g, bias); col.b = (uint8)Math.Lerp(col.b,
					neighbourColor.b, bias); col.a = (uint8)Math.Lerp(col.a, neighbourColor.a, bias);
							}
						}
					}*/
					DrawUtils.SetPixel((uint32*)data, _renderedImage, x, y, col);
				}
			}

			SDL.UnlockTexture(_renderedImage.mTexture);
			SDL.SetRenderTarget(renderer, target);
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
}
