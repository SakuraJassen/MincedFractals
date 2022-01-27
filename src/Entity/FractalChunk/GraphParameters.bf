namespace MincedFractals.Entity.FractalChunk
{
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

		public static GraphParameters operator-(GraphParameters lhs, GraphParameters rhs)
		{
			var newParameters = GraphParameters();
			newParameters.yMin = lhs.yMin - rhs.yMin;
			newParameters.yMax = lhs.yMax - rhs.yMax;
			newParameters.yOffset = lhs.yOffset - rhs.yOffset;
			newParameters.xMin = lhs.xMin - rhs.xMin;
			newParameters.xMax = lhs.xMax - rhs.xMax;
			newParameters.xOffset = lhs.xOffset - rhs.xOffset;
			newParameters.kMax = lhs.kMax - rhs.kMax;
			newParameters.zoomScale = lhs.zoomScale - rhs.zoomScale;
			return newParameters;
		}

		public static GraphParameters operator+(GraphParameters lhs, GraphParameters rhs)
		{
			var newParameters = GraphParameters();
			newParameters.yMin = lhs.yMin + rhs.yMin;
			newParameters.yMax = lhs.yMax + rhs.yMax;
			newParameters.yOffset = lhs.yOffset + rhs.yOffset;
			newParameters.xMin = lhs.xMin + rhs.xMin;
			newParameters.xMax = lhs.xMax + rhs.xMax;
			newParameters.xOffset = lhs.xOffset + rhs.xOffset;
			newParameters.kMax = lhs.kMax + rhs.kMax;
			newParameters.zoomScale = lhs.zoomScale + rhs.zoomScale;
			return newParameters;
		}

		public static GraphParameters operator/(GraphParameters lhs, GraphParameters rhs)
		{
			var newParameters = GraphParameters();
			newParameters.yMin = lhs.yMin / rhs.yMin;
			newParameters.yMax = lhs.yMax / rhs.yMax;
			newParameters.yOffset = lhs.yOffset / rhs.yOffset;
			newParameters.xMin = lhs.xMin / rhs.xMin;
			newParameters.xMax = lhs.xMax / rhs.xMax;
			newParameters.xOffset = lhs.xOffset / rhs.xOffset;
			newParameters.kMax = lhs.kMax / rhs.kMax;
			newParameters.zoomScale = lhs.zoomScale / rhs.zoomScale;
			return newParameters;
		}

		public static GraphParameters operator*(GraphParameters lhs, GraphParameters rhs)
		{
			var newParameters = GraphParameters();
			newParameters.yMin = lhs.yMin * rhs.yMin;
			newParameters.yMax = lhs.yMax * rhs.yMax;
			newParameters.yOffset = lhs.yOffset * rhs.yOffset;
			newParameters.xMin = lhs.xMin * rhs.xMin;
			newParameters.xMax = lhs.xMax * rhs.xMax;
			newParameters.xOffset = lhs.xOffset * rhs.xOffset;
			newParameters.kMax = lhs.kMax * rhs.kMax;
			newParameters.zoomScale = lhs.zoomScale * rhs.zoomScale;
			return newParameters;
		}
	}
}
