using System.Collections;
using System;
namespace MincedFractals.Math
{
	public struct GraphParameters
	{
		public double yMin = -1.12;// Default minimum Y for the set to render.
		public double yMax = 1.12;// Default maximum Y for the set to render., 1.12, -2.0, 0.47
		public double yOffset = 0;// Default maximum Y for the set to render.
		public double xMin = -2.0;// Default minimum X for the set to render.
		public double xMax = 0.47;// Default maximum X for the set to render.
		public double xOffset = 0;// Default maximum X for the set to render.
		public double kMax = 50;
		public double zoomScale = 1;// Default amount to zoom in by.

		public Result<void> Parse<T>(List<T> lines) mut where StringView : operator implicit T
		{
			if (lines.Count < 6)
				return .Err;
			int cnt = 0;
			yMin = Double.Parse(lines[cnt++]);
			yMax = Double.Parse(lines[cnt++]);
			xMin = Double.Parse(lines[cnt++]);
			xMax = Double.Parse(lines[cnt++]);
			kMax = Double.Parse(lines[cnt++]);
			zoomScale = Double.Parse(lines[cnt++]);

			return .Ok;
		}

		[Comptime]
		public void ApplyToType(Type type)
		{
			Compiler.EmitTypeBody(type, "public override void ToString(String str)\n{\n");
			for (var fieldInfo in type.GetFields())
			{
				if (!fieldInfo.IsInstanceField)
					continue;
				if (@fieldInfo.Index > 0)
					Compiler.EmitTypeBody(type, "\tstr.Append(\", \");\n");
				Compiler.EmitTypeBody(type, scope $"\tstr.AppendF($\"{fieldInfo.Name}={{ {fieldInfo.Name} }}\");\n");
			}
			Compiler.EmitTypeBody(type, "}");
		}

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
