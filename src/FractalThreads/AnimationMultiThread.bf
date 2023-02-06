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
	class AniThread
	{
		public RenderThread _renderThread = null ~ SafeDelete!(_);;
		public List<IdGraph> animationHistory = null ~ SafeDelete!(_);
		public int animationIndex = 0;
		public bool animationRunning = false;

		public struct IdGraph
		{
			public GraphParameters gp;
			public int id;

			public this(GraphParameters graph, int ident)
			{
				gp = graph;
				id = ident;
			}
		}
	}

	public class AnimationMultiThread
	{
		List<AniThread> _threadList = new List<AniThread>() ~ DeleteContainerAndItems!(_);
		int NumRenderThreads = 4;
		bool saveAnimation = false;
		bool instantPresent = true;
		Image mCurrentImage = null ~ SafeDelete!(_);
		int presentDelay = -1;
		Stopwatch presentDelayer = new Stopwatch() ~ SafeDelete!(_);
		public List<GraphParameters> CompletAnimationHistory = new List<GraphParameters>() ~ SafeDelete!(_);

		public bool AnimationRunning
		{
			get
			{
				for (var t in _threadList)
				{
					if (t.animationRunning == true)
						return true;
				}
				return false;
			}
		}

		public bool RenderingDone
		{
			get
			{
				for (var t in _threadList)
				{
					if (t._renderThread.IsAlive == true)
						return false;
				}
				return true;
			}
		}
		SDL.Rect _targetRect = default;

		FractalChunkMultiThread _fc = null ~ _ = null;

		public this(FractalChunkMultiThread fc, int numThreads)
		{
			_fc = fc;
			NumRenderThreads = numThreads;
			Init();
		}

		public void Init()
		{
			DeleteContainerAndItems!(_threadList);
			_threadList = new List<AniThread>();
			for (int32 i in 0 ..< NumRenderThreads)
			{
				var t = new AniThread();
				t._renderThread = new RenderThread(new Thread(new () => _fc.RenderImageByPixel(_threadList[i]._renderThread, _threadList[i].animationHistory[_threadList[i].animationIndex++].gp, v2d<int>(1), v2d<int>(0), .(0), false)), false, _fc.[Friend]mSize);
				t.animationHistory = new List<AniThread.IdGraph>();
				_threadList.Add(t);
			}
		}

		public void StopAnimation()
		{
			presentDelay = -1;
			_targetRect = .(0, 0, 0, 0);
			for (var thread in _threadList)
			{
				thread._renderThread.RequestAbort();
				thread.animationRunning = false;
			}
			while (!RenderingDone)
			{
				SDL.Delay(10);// Wait for the threads to terminate before we free the resources.
			}
			SafeMemberSet!(mCurrentImage, null);
		}

		public void AnimateHistory()
		{
			for (var i in ..<_threadList.Count)
			{
				var t = _threadList[i];
				var animationIndex = t.animationIndex;
				if (t != null)
				{
					if (!t._renderThread.IsAlive)
					{
						if (presentDelay == -1)
						{
							presentDelay = t._renderThread.RenderTime;

							_targetRect = .(0, 0, 0, 0);

	//						Logger.Debug(TimeSpan(presentDelay), presentDelay);

							presentDelayer.Restart();
							SafeMemberSet!(mCurrentImage, t._renderThread.[Friend]_renderedImage);

							if (saveAnimation)
							{
								var basename = scope String();
								basename.AppendF(".\\png\\ani\\{}.png", t.animationHistory[animationIndex - 1].id);
								SDLError!(mCurrentImage.SaveTexture(basename, gGameApp.mRenderer));
							}
							t._renderThread.[Friend]_renderedImage = null;

							if ((animationIndex) < t.animationHistory.Count && animationIndex >= 1)
							{
								var next = t.animationHistory[animationIndex].gp;

								var manager = _fc.GetScreenPixelManager(t.animationHistory[animationIndex - 1].gp);
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
							if (animationIndex >= t.animationHistory.Count)
							{
								StopAnimation();
								return;
							}

							_fc.ClearPixelBuffer();
							SafeMemberSet!(t._renderThread, new RenderThread(new Thread(new () => _fc.RenderImageByPixel(t._renderThread, t.animationHistory[t.animationIndex++].gp, v2d<int>(1), v2d<int>(0), .(0), false)), false, _fc.[Friend]mSize));
							t._renderThread.Enabled = true;
							t._renderThread.StartThread();
							presentDelayer.Stop();
							presentDelayer.Reset();
							presentDelay = -1;
						}
						else
						{
							t._renderThread.[Friend]_renderTime = presentDelayer.ElapsedMicroseconds + presentDelay;
						}
					}
				}
			}
		}

		public void StartAnimation(bool save = false)
		{
			for (var thread in _threadList)
			{
				thread.animationHistory.Clear();
			}
			var threadID = 0;
			for (var i in ..<CompletAnimationHistory.Count)
			{
				var gp = CompletAnimationHistory[i];

				_threadList[threadID].animationHistory.Add(.(gp, i));

				if (++threadID == _threadList.Count)
					threadID = 0;
			}

			for (var thread in _threadList)
			{
				if (thread.animationHistory.Count == 0)
					continue;
				if (thread.animationRunning)
				{
					thread._renderThread.RequestAbort();
					while (!RenderingDone)
					{
						SDL.Delay(10);// Wait for the threads to terminate before we free the resources.
					}
				}
				thread.animationIndex = 0;

				//StartNextFrame(ref thread._renderThread, thread.animationHistory[thread.animationIndex++], save);
				StartNextFrame(thread, save);
				thread.animationRunning = true;
			}
			saveAnimation = save;
		}

		public void StartNextFrame(AniThread t, bool save = false)
		{
			_fc.ClearPixelBuffer();
			SafeMemberSet!(t._renderThread, new RenderThread(new Thread(new () => _fc.RenderImageByPixel(t._renderThread, t.animationHistory[t.animationIndex++].gp, v2d<int>(1), v2d<int>(0), .(0), false)), false, _fc.[Friend]mSize));
			t._renderThread.Enabled = true;
			t._renderThread.StartThread();
		}

		public void StartNextFrame(ref RenderThread t, GraphParameters gp, bool save = false)
		{
			_fc.ClearPixelBuffer();
			SafeMemberSet!(t, new RenderThread(new Thread(new () => _fc.RenderImageByPixel(t, gp, v2d<int>(1), v2d<int>(0), .(0), false)), false, _fc.[Friend]mSize));
			t.Enabled = true;
			t.StartThread();
		}

		public void CopyGraphHistory(List<GraphParameters> gp)
		{
			CompletAnimationHistory.Clear();
			for (var para in gp)
			{
				CompletAnimationHistory.Add(para);
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
			for (int i in ..<CompletAnimationHistory.Count)
			{
				buffer.Add(CompletAnimationHistory[i]);
				if (i + 1 < CompletAnimationHistory.Count)
				{
					var currentPara = CompletAnimationHistory[i];
					var nextPara = CompletAnimationHistory[i + 1];
					var manager = _fc.GetScreenPixelManager(currentPara);

					//var diff = current - next;
					var currentSize = _getSizeInPixels(manager, v2d<double>(currentPara.xMin, currentPara.yMin), v2d<double>(currentPara.xMax, currentPara.yMax));
					var nextSize = _getSizeInPixels(manager, v2d<double>(nextPara.xMin, nextPara.yMin), v2d<double>(nextPara.xMax, nextPara.yMax));
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
			for (int i in ..<CompletAnimationHistory.Count)
			{
				buffer.Add(CompletAnimationHistory[i]);
				if (i + 1 < CompletAnimationHistory.Count)
				{
					var current = CompletAnimationHistory[i];
					var next = CompletAnimationHistory[i + 1];
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
