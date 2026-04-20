using Unity.Mathematics;
using UnityEngine;
using UnityEngine.UIElements;


public class TextureCreator : MonoBehaviour {
	// Add your own pattern types here:
	public enum PatternType { Noise, None, Mandelbrot, UV, Columns, Checkers, Circle, PerlinNoise, SimplexNoise, SineWave, Gradient, MultiHill };

    public float rotateAngle;

	public PatternType patternType;

	const int SIZE = 1024;

	Texture2D texture = null;
	Color[] cols = null;

	void Start() {
		// Create a texture and pass it to the material of this game object's renderer:
		Renderer rend = GetComponent<Renderer>();
		texture = new Texture2D(SIZE, SIZE, TextureFormat.RGBA32, false);
		rend.material.mainTexture = texture;
		texture.wrapMode = TextureWrapMode.Clamp;

		Draw();
	}

	/// <summary>
	/// Returns the pixel color for texture coordinate (u,v), for a given pattern.
	/// </summary>
	Color CalculatePixelColor(Vector2 uv, PatternType pattern) {
		// TODO: insert your own pattern creation code here.
		//  See the slides for details.
        switch (pattern) {
			case PatternType.Noise: // white noise				
				return UnityEngine.Random.value * Color.white;
			case PatternType.Mandelbrot:
				return Mandelbrot(3 * (uv.x - 0.75f), 3 * (uv.y - 0.5f));
			case PatternType.UV:
				return new Color(uv.x, uv.y, 0, 1);
			case PatternType.Columns:
				return Columns(uv.x);
			case PatternType.Checkers:
				return Checkers(uv);
			case PatternType.Circle:
				return Circle(uv);
			case PatternType.PerlinNoise:
				return PerlinNoise(uv);
			case PatternType.SimplexNoise:
				return SimplexNoise(uv);
            case PatternType.SineWave:
                return SineWave(uv);
            case PatternType.Gradient:
                return Gradient(uv);
            case PatternType.MultiHill:
                return MultiHill(uv);
            default:
				return Color.blue;
		}
	}

	Color Columns(float u)
	{
        float size = 0.1f;
        bool white = Mathf.Abs(u+1) * (1 / size) % 2 > 1;
        return white ? Color.white : Color.black;
    }

	Color Checkers(Vector2 uv)
	{
        float size = 0.1f;
        Vector2 pos = new Vector2(Mathf.Floor(Mathf.Abs(uv.x + 1) / size), Mathf.Floor(Mathf.Abs(uv.y + 1) / size));
        bool white = (pos.x + (pos.y % 2)) % 2 > 0;
        return white ? Color.magenta : Color.black;
    }

	Color Circle(Vector2 uv)
	{
		float circleSize = 0.4f;
		bool white = Vector2.Distance(uv, new Vector2(0.5f, 0.5f)) < circleSize;
		return white ? Color.white : Color.black;
	}

	Color PerlinNoise(Vector2 uv)
	{
		float scale = 50;
		uv *= scale;
		return Color.white * Mathf.PerlinNoise(uv.x, uv.y);
    }

	Color SimplexNoise(Vector2 uv)
	{
        float scale = 50f;
        return Color.white * Generate(uv.x * scale, uv.y * scale);
    }

    Color SineWave(Vector2 uv)
    {
        float x = uv.x * 2 * Mathf.PI;
        float y = Mathf.Cos(x) * 0.5f + 0.5f;
        return uv.y > y ? Color.white : Color.black;
    }

    Color Gradient(Vector2 uv)
    {
        float x = uv.x * 2 * Mathf.PI;
        float y = Mathf.Cos(x) * 0.5f + 0.5f;
        return Color.magenta * y;
    }

    Color MultiHill(Vector2 uv)
    {
        Color col = Color.black;
        for(int i = 0; i < 3; i++)
        {
            float x = ((uv.x) * 2 * Mathf.PI) + (float)(i / 3);
            float y = Mathf.Cos(x) * 0.5f + 0.5f;
            if (uv.y < y)
            {
                switch (i)
                {
                    case 0:
                        col += Color.red;
                        break;
                    case 1:
                        col += Color.green;
                        break;
                    case 2:
                        col += Color.blue;
                        break;
                    default:
                        break;
                }
            }
        }
        return col;
    }

	/// <summary>
	/// Draws a pattern given by the [pattern] number to the [cols] array, which
	/// should have size [width] * [height].
	/// </summary>
	void DrawPattern(Color[] cols, int width, int height, PatternType pattern) {
		for (int i = 0; i < width; i++) {
			for (int j = 0; j < height; j++)
			{
                Vector2 uv = new Vector2((float)i / width, (float)j / height);
                uv = uv - new Vector2(0.5f, 0.5f);
                float angle = rotateAngle * 0.0174533f;
                uv = new Vector2(uv.x * Mathf.Cos(angle) - uv.y * Mathf.Sin(angle), uv.x * Mathf.Sin(angle) + uv.y * Mathf.Cos(angle));
                uv = uv + new Vector2(0.5f, 0.5f);
                cols[j*width + i] = CalculatePixelColor(uv, pattern);
            }
		}
	}

	void Draw() {
		if (cols == null) {
			cols = texture.GetPixels();
		}
		DrawPattern(cols, SIZE, SIZE, patternType);

		texture.SetPixels(cols);
		texture.Apply();
	}

	// OnValidate is called whenever an inspector value is changed - even in edit mode!
	void OnValidate() {
		// To prevent calling Draw code in edit mode,
		// we check whether a texture has been created (in Start)
		if (texture == null) return;
		Draw();
	}

	private void Update() {
		// Control + S saves to file:
		if (Input.GetKeyDown(KeyCode.S) && (Input.GetKey(KeyCode.LeftShift) || Input.GetKey(KeyCode.RightShift))) {
			var exporter = GetComponent<TextureExporter>();
			if (exporter != null) {
				exporter.ExportTexture(texture);
			}
		}
	}

	#region Mandelbrot
	// Used for the Mandelbrot fractal:
	const int maxIterations = 30;
	const float escapeLengthSquared = 4;

	Color Mandelbrot(float cReal, float cImaginary) {
		int iteration = 0;

		float zReal = 0;
		float zImaginary = 0;

		while (zReal * zReal + zImaginary * zImaginary < escapeLengthSquared && iteration < maxIterations) {
			// Use Mandelbrot's magic iteration formula: z := z^2 + c 
			// (using complex number multiplication & addition - 
			//   see https://mathbitsnotebook.com/Algebra2/ComplexNumbers/CPArithmeticASM.html)
			float newZr = zReal * zReal - zImaginary * zImaginary + cReal;
			zImaginary = 2 * zReal * zImaginary + cImaginary;
			zReal = newZr;
			iteration++;
		}
		// Return a color value based on the number of iterations that were needed to "escape the circle":
		float grad = 1f * iteration / maxIterations; // between 0 and 1
													 // TODO: use a nicer gradient
		return new Color(grad, grad, grad);
	}
    #endregion

    float Generate(float x, float y)
    {
        const float F2 = 0.366025403f; // F2 = 0.5*(sqrt(3.0)-1.0)
        const float G2 = 0.211324865f; // G2 = (3.0-Math.sqrt(3.0))/6.0

        float n0, n1, n2; // Noise contributions from the three corners

        // Skew the input space to determine which simplex cell we're in
        var s = (x + y) * F2; // Hairy factor for 2D
        var xs = x + s;
        var ys = y + s;
        var i = FastFloor(xs);
        var j = FastFloor(ys);

        var t = (i + j) * G2;
        var X0 = i - t; // Unskew the cell origin back to (x,y) space
        var Y0 = j - t;
        var x0 = x - X0; // The x,y distances from the cell origin
        var y0 = y - Y0;

        // For the 2D case, the simplex shape is an equilateral triangle.
        // Determine which simplex we are in.
        int i1, j1; // Offsets for second (middle) corner of simplex in (i,j) coords
        if (x0 > y0) { i1 = 1; j1 = 0; } // lower triangle, XY order: (0,0)->(1,0)->(1,1)
        else { i1 = 0; j1 = 1; }      // upper triangle, YX order: (0,0)->(0,1)->(1,1)

        // A step of (1,0) in (i,j) means a step of (1-c,-c) in (x,y), and
        // a step of (0,1) in (i,j) means a step of (-c,1-c) in (x,y), where
        // c = (3-sqrt(3))/6

        var x1 = x0 - i1 + G2; // Offsets for middle corner in (x,y) unskewed coords
        var y1 = y0 - j1 + G2;
        var x2 = x0 - 1.0f + 2.0f * G2; // Offsets for last corner in (x,y) unskewed coords
        var y2 = y0 - 1.0f + 2.0f * G2;

        // Wrap the integer indices at 256, to avoid indexing perm[] out of bounds
        var ii = Mod(i, 256);
        var jj = Mod(j, 256);

        // Calculate the contribution from the three corners
        var t0 = 0.5f - x0 * x0 - y0 * y0;
        if (t0 < 0.0f) n0 = 0.0f;
        else
        {
            t0 *= t0;
            n0 = t0 * t0 * Grad(_perm[ii + _perm[jj]], x0, y0);
        }

        var t1 = 0.5f - x1 * x1 - y1 * y1;
        if (t1 < 0.0f) n1 = 0.0f;
        else
        {
            t1 *= t1;
            n1 = t1 * t1 * Grad(_perm[ii + i1 + _perm[jj + j1]], x1, y1);
        }

        var t2 = 0.5f - x2 * x2 - y2 * y2;
        if (t2 < 0.0f) n2 = 0.0f;
        else
        {
            t2 *= t2;
            n2 = t2 * t2 * Grad(_perm[ii + 1 + _perm[jj + 1]], x2, y2);
        }

        // Add contributions from each corner to get the final noise value.
        // The result is scaled to return values in the interval [-1,1].
        return 40.0f * (n0 + n1 + n2); // TODO: The scale factor is preliminary!
    }


    byte[] _perm = {
            151,160,137,91,90,15,
            131,13,201,95,96,53,194,233,7,225,140,36,103,30,69,142,8,99,37,240,21,10,23,
            190, 6,148,247,120,234,75,0,26,197,62,94,252,219,203,117,35,11,32,57,177,33,
            88,237,149,56,87,174,20,125,136,171,168, 68,175,74,165,71,134,139,48,27,166,
            77,146,158,231,83,111,229,122,60,211,133,230,220,105,92,41,55,46,245,40,244,
            102,143,54, 65,25,63,161, 1,216,80,73,209,76,132,187,208, 89,18,169,200,196,
            135,130,116,188,159,86,164,100,109,198,173,186, 3,64,52,217,226,250,124,123,
            5,202,38,147,118,126,255,82,85,212,207,206,59,227,47,16,58,17,182,189,28,42,
            223,183,170,213,119,248,152, 2,44,154,163, 70,221,153,101,155,167, 43,172,9,
            129,22,39,253, 19,98,108,110,79,113,224,232,178,185, 112,104,218,246,97,228,
            251,34,242,193,238,210,144,12,191,179,162,241, 81,51,145,235,249,14,239,107,
            49,192,214, 31,181,199,106,157,184, 84,204,176,115,121,50,45,127, 4,150,254,
            138,236,205,93,222,114,67,29,24,72,243,141,128,195,78,66,215,61,156,180,
            151,160,137,91,90,15,
            131,13,201,95,96,53,194,233,7,225,140,36,103,30,69,142,8,99,37,240,21,10,23,
            190, 6,148,247,120,234,75,0,26,197,62,94,252,219,203,117,35,11,32,57,177,33,
            88,237,149,56,87,174,20,125,136,171,168, 68,175,74,165,71,134,139,48,27,166,
            77,146,158,231,83,111,229,122,60,211,133,230,220,105,92,41,55,46,245,40,244,
            102,143,54, 65,25,63,161, 1,216,80,73,209,76,132,187,208, 89,18,169,200,196,
            135,130,116,188,159,86,164,100,109,198,173,186, 3,64,52,217,226,250,124,123,
            5,202,38,147,118,126,255,82,85,212,207,206,59,227,47,16,58,17,182,189,28,42,
            223,183,170,213,119,248,152, 2,44,154,163, 70,221,153,101,155,167, 43,172,9,
            129,22,39,253, 19,98,108,110,79,113,224,232,178,185, 112,104,218,246,97,228,
            251,34,242,193,238,210,144,12,191,179,162,241, 81,51,145,235,249,14,239,107,
            49,192,214, 31,181,199,106,157,184, 84,204,176,115,121,50,45,127, 4,150,254,
            138,236,205,93,222,114,67,29,24,72,243,141,128,195,78,66,215,61,156,180
        };


    int FastFloor(float x)
    {
        return (x > 0) ? ((int)x) : (((int)x) - 1);
    }

   int Mod(int x, int m)
    {
        var a = x % m;
        return a < 0 ? a + m : a;
    }

    float Grad(int hash, float x, float y)
    {
        var h = hash & 7;      // Convert low 3 bits of hash code
        var u = h < 4 ? x : y;  // into 8 simple gradient directions,
        var v = h < 4 ? y : x;  // and compute the dot product with (x,y).
        return ((h & 1) != 0 ? -u : u) + ((h & 2) != 0 ? -2.0f * v : 2.0f * v);
    }
}
