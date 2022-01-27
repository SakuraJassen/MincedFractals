using SDL2;
using System.Threading;
using BasicEngine;
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
