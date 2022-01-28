using System;
using BasicEngine.Debug;
using BasicEngine;
namespace MincedFractals
{
		/// <summary>
		/// Class used for colour lookup table.
		/// </summary>
	public class ColourTable
	{
		public int kMax;
		public int nColour;
		private double scale;
		private SDL2.SDL.Color[] colourTable ~ SafeDelete!(_);

		/// <summary>
		/// Constructor. Creates lookup table.
		/// </summary>
		/// <param name="n"></param>
		/// <param name="kMax"></param>
		public this(int kMax) : this(kMax, kMax)
		{
		}

		public this(int n, int kMax)
		{
			nColour = n;
			this.kMax = kMax;
			scale = ((double)nColour) / kMax;
			colourTable = new SDL2.SDL.Color[nColour];

			for (int i = 0; i < nColour / 2; i++)
			{
				double colourIndex = ((double)i) / nColour;
				double hue = Math.Pow(colourIndex, 0.25);
				Logger.Debug(colourIndex);
				var color = ColorFromHSLA(hue, 0.9, 0.6);
				colourTable[i] = color;
				colourTable[^(i + 1)] = color;
			}
			for (var _ in ...10)
			{
				Smooth();
			}
		}

		/// <summary>
		/// Retrieve the colour from iteration count k.
		/// </summary>
		/// <param name="k"></param>
		/// <returns></returns>
		public SDL2.SDL.Color GetColour(int k)
		{
			return colourTable[k % nColour];
		}

		public void Smooth()
		{
			SDL2.SDL.Color[] buffer = scope SDL2.SDL.Color[nColour];
			var pct = 0.7f;
			for (int i = 0; i < nColour - 1; i++)
			{
				//Color colDiff = scope .((uint8), (uint8), (uint8));
				var R = Math.Lerp(colourTable[i].r, colourTable[i + 1].r, pct);
				var G = Math.Lerp(colourTable[i].g, colourTable[i + 1].g, pct);
				var B = Math.Lerp(colourTable[i].b, colourTable[i + 1].b, pct);

				buffer[i].r = (uint8)(R);
				buffer[i].g = (uint8)(G);
				buffer[i].b = (uint8)(B);
			}
			{// Last and first smooth
				var R = Math.Lerp(colourTable[^1].r, colourTable[0].r, pct);
				var G = Math.Lerp(colourTable[^1].g, colourTable[0].g, pct);
				var B = Math.Lerp(colourTable[^1].b, colourTable[0].b, pct);

				buffer[^1].r = (uint8)(R);
				buffer[^1].g = (uint8)(G);
				buffer[^1].b = (uint8)(B);

				/*R = Math.Lerp(colourTable[0].r, colourTable[^1].r, pct);
				G = Math.Lerp(colourTable[0].g, colourTable[^1].g, pct);
				B = Math.Lerp(colourTable[0].b, colourTable[^1].b, pct);
				R = Math.Lerp(R, buffer[0].r, 0.5f);
				G = Math.Lerp(G, buffer[0].g, 0.5f);
				B = Math.Lerp(B, buffer[0].b, 0.5f);
				buffer[0].r = (uint8)(R);
				buffer[0].g = (uint8)(G);
				buffer[0].b = (uint8)(B);*/
			}

			/*for (int i = nColour - 1; i > 0; i--)
			{
				//Color colDiff = scope .((uint8), (uint8), (uint8));
				var R = Math.Lerp(colourTable[i].r, colourTable[i - 1].r, pct);
				var G = Math.Lerp(colourTable[i].g, colourTable[i - 1].g, pct);
				var B = Math.Lerp(colourTable[i].b, colourTable[i - 1].b, pct);
				R = Math.Lerp(R, buffer[i].r, 0.5f);
				G = Math.Lerp(G, buffer[i].g, 0.5f);
				B = Math.Lerp(B, buffer[i].b, 0.5f);
				buffer[i].r = (uint8)(R);
				buffer[i].g = (uint8)(G);
				buffer[i].b = (uint8)(B);
			}*/

			for (int i = 0; i < nColour; i++)
			{
				colourTable[i] = buffer[i];
			}
		}

		/// <summary>
		/// Convert HSL colour value to Color object.
		/// </summary>
		/// <param name="H">Hue</param>
		/// <param name="S">Saturation</param>
		/// <param name="L">Lightness</param>
		/// <returns>Color object</returns>
		public static SDL2.SDL.Color ColorFromHSLA(double H, double S, double L)
		{
			var H;
			var S;
			var L;
			double v;
			double r, g, b;

			r = L;// Set RGB all equal to L, defaulting to grey.
			g = L;
			b = L;

			// Standard HSL to RGB conversion. This is described in
			// detail at:
			// http://www.niwa.nu/2013/05/math-behind-colorspace-conversions-rgb-hsl/
			v = (L <= 0.5) ? (L * (1.0 + S)) : (L + S - L * S);

			if (v > 0)
			{
				double m;
				double sv;
				int sextant;
				double fract, vsf, mid1, mid2;

				m = L + L - v;
				sv = (v - m) / v;
				H *= 6.0;
				sextant = (int)H;
				fract = H - sextant;
				vsf = v * sv * fract;
				mid1 = m + vsf;
				mid2 = v - vsf;

				switch (sextant) {
				case 0:
					r = v;
					g = mid1;
					b = m;
					break;

				case 1:
					r = mid2;
					g = v;
					b = m;
					break;

				case 2:
					r = m;
					g = v;
					b = mid1;
					break;

				case 3:
					r = m;
					g = mid2;
					b = v;
					break;

				case 4:
					r = mid1;
					g = m;
					b = v;
					break;

				case 5:
					r = v;
					g = m;
					b = mid2;
					break;
				}
			}

			SDL2.SDL.Color color = SDL2.SDL.Color((uint8)(r * 255), (uint8)(g * 255), (uint8)(b * 255), 0xFF);
			return color;
		}
	}
}
