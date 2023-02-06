using System.Diagnostics;
using System.Collections;
using SDL2;
using System.Threading;
using System;
using BasicEngine.Debug;
using BasicEngine;
using MincedFractals.Math;
using MincedFractals.Entity;

namespace MincedFractals.RenderThreads
{
	public class AnimationThread
	{
		RenderThread _renderThread = null ~ SafeDelete!(_);
		const int NumRenderThreads = 4;
		int animationIndex = 0;
		bool animationRunning = false;
		bool saveAnimation = false;
		bool instantPresent = true;
		Image mCurrentImage = null ~ SafeDelete!(_);
		int presentDelay = -1;
		Stopwatch presentDelayer = new Stopwatch() ~ SafeDelete!(_);
		public List<GraphParameters> animationHistory = new List<GraphParameters>() ~ SafeDelete!(_);

		public bool IsAlive { get { return (bool)_renderThread?.IsAlive; } }
		SDL.Rect _targetRect = default;

		FractalChunkMultiThread _fc = null ~ _ = null;

		public this(FractalChunkMultiThread fc)
		{
			_fc = fc;
			SafeMemberSet!(_renderThread, new RenderThread(new Thread(new () => fc.RenderImageByPixel(_renderThread, animationHistory[animationIndex++], v2d<int>(1), .(0), .(0), false)), false, fc.[Friend]mSize));
		}

		public void StopAnimation()
		{
			animationRunning = false;
			presentDelay = -1;
			_targetRect = .(0, 0, 0, 0);
			SafeMemberSet!(mCurrentImage, null);
		}

		public void AnimateHistory()
		{
			if (_renderThread != null)
			{
				if (!_renderThread.IsAlive)
				{
					if (presentDelay == -1)
					{
						presentDelay = _renderThread.RenderTime;

						_targetRect = .(0, 0, 0, 0);

//						Logger.Debug(TimeSpan(presentDelay), presentDelay);

						presentDelayer.Restart();
						SafeMemberSet!(mCurrentImage, _renderThread.[Friend]_renderedImage);
						_renderThread.[Friend]_renderedImage = null;

						if (saveAnimation)
						{
							var basename = scope String();
							basename.AppendF(".\\png\\ani\\{}.png", animationIndex);
							SDLError!(mCurrentImage.SaveTexture(basename, gGameApp.mRenderer));
						}
						if ((animationIndex) < animationHistory.Count && animationIndex >= 1)
						{
							var next = animationHistory[animationIndex];
							var manager = _fc.GetScreenPixelManager(animationHistory[animationIndex - 1]);
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

						_fc.ClearPixelBuffer();
						SafeMemberSet!(_renderThread, new RenderThread(new Thread(new () => _fc.RenderImageByPixel(_renderThread, animationHistory[animationIndex++], v2d<int>(1), .(0), .(0), false)), false, _fc.[Friend]mSize));
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

		public void StartAnimation(bool save = false)
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
			StartNextFrame(save);
			animationRunning = true;
			saveAnimation = save;
		}

		public void StartNextFrame(bool save = false)
		{
			_fc.ClearPixelBuffer();
			SafeMemberSet!(_renderThread, new RenderThread(new Thread(new () => _fc.RenderImageByPixel(_renderThread, animationHistory[animationIndex++], v2d<int>(1), v2d<int>(0), .(0), false)), false, _fc.[Friend]mSize));
			_renderThread.Enabled = true;
			_renderThread.StartThread();
		}

		public void CopyGraphHistory(List<GraphParameters> gp)
		{
			animationHistory.Clear();
			for (var para in gp)
			{
				animationHistory.Add(para);
			}
		}

		private v2d<double> _getSizeInPixels(ScreenPixelManage manager, v2d<double> botLeft, v2d<double> topRight)
		{
			var minPixelPos = manager.GetPixelCoord(botLeft);// bot left h,0
			var maxPixelPos = manager.GetPixelCoord(topRight);//top right 0,w
			var width = (maxPixelPos.x - minPixelPos.x);
			var height = (minPixelPos.y - maxPixelPos.y);
			return .(width, height);
		}

		public void SmoothAnimation(double pixelPerSec, double fps = 1)
		{
			List<GraphParameters> buffer = scope List<GraphParameters>();
			for (int i in ..<animationHistory.Count)
			{
				buffer.Add(animationHistory[i]);
				if (i + 1 < animationHistory.Count)
				{
					var currentPara = animationHistory[i];
					var nextPara = animationHistory[i + 1];
					var manager = _fc.GetScreenPixelManager(currentPara);

					//var diff = current - next;
					var currentSize = _getSizeInPixels(manager, v2d<double>(currentPara.xMin, currentPara.yMin), v2d<double>(currentPara.xMax, currentPara.yMax));//top right 0,w
					var nextSize = _getSizeInPixels(manager, v2d<double>(nextPara.xMin, nextPara.yMin), v2d<double>(nextPara.xMax, nextPara.yMax));//top right 0,w
					var sizeDiff = currentSize - nextSize;
					var totalFrameCount = (sizeDiff.x / pixelPerSec) * fps;
					var stepSizeY = (sizeDiff.x / pixelPerSec) * fps;
					var pctX = 1 / totalFrameCount;
					var pctY = 1 / stepSizeY;
					for (int frameCnt = 1; frameCnt < totalFrameCount; frameCnt++)
					{
						GraphParameters gp = GraphParameters();
						if (pctX * frameCnt >= 1f)
							break;
						gp.xMin = Math.Lerp(currentPara.xMin, nextPara.xMin, (double)(pctX * frameCnt));
						gp.xMax = Math.Lerp(currentPara.xMax, nextPara.xMax, (double)(pctX * frameCnt));
						gp.yMin = Math.Lerp(currentPara.yMin, nextPara.yMin, (double)(pctY * frameCnt));
						gp.yMax = Math.Lerp(currentPara.yMax, nextPara.yMax, (double)(pctY * frameCnt));
						gp.kMax = Math.Lerp(currentPara.kMax, nextPara.kMax, (double)(pctX * frameCnt));
						buffer.Add(gp);
					}
					SafeDelete!(manager);
				}
			}

			CopyGraphHistory(buffer);
		}

		public void SmoothAnimation(double pct)
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
						gp.xMin = Math.Lerp(current.xMin, next.xMin, (double)(pct * x));
						gp.xMax = Math.Lerp(current.xMax, next.xMax, (double)(pct * x));
						gp.yMin = Math.Lerp(current.yMin, next.yMin, (double)(pct * x));
						gp.yMax = Math.Lerp(current.yMax, next.yMax, (double)(pct * x));
						gp.kMax = Math.Lerp(current.kMax, next.kMax, (double)(pct * x));
						buffer.Add(gp);
						if (x == 9)
						{
							NOP!();
						}
					}
				}
			}

			CopyGraphHistory(buffer);
		}
	}
}
