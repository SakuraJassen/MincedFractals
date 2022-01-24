using System;
namespace FractelOPOP
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
		public this(int n, int kMax)
		{
			nColour = n;
			this.kMax = kMax;
			scale = ((double)nColour) / kMax;
			colourTable = new SDL2.SDL.Color[nColour];

			for (int i = 0; i < nColour; i++)
			{
				double colourIndex = ((double)i) / nColour;
				double hue = Math.Pow(colourIndex, 0.25);
				colourTable[i] = ColorFromHSLA(hue, 0.9, 0.6);
			}
		}

		/// <summary>
		/// Retrieve the colour from iteration count k.
		/// </summary>
		/// <param name="k"></param>
		/// <returns></returns>
		public SDL2.SDL.Color GetColour(int k)
		{
			if (k >= nColour)
				return colourTable[^1];

			return colourTable[k];
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

			// Create Color object from RGB values.
			SDL2.SDL.Color color = SDL2.SDL.Color((uint8)(r * 255), (uint8)(g * 255), (uint8)(b * 255), 0xFF);
			return color;
		}
	}
}
