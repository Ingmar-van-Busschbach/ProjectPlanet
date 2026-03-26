using UnityEngine;

[System.Serializable]
public class SimpleNoiseSettings
{
    [Tooltip("Amount of perlin noise layers")]
    public int octaves = 4;
    [Tooltip("Rate at which the frequency changes with each layer")]
    public float lacunarity = 2;
    [Tooltip("Rate at which the amplitude changes with each layer")]
    public float persistence = 0.5f;
    [Tooltip("Scale of the generated noise map, which essentially scales the initial frequency of the first layer.")]
    public float scale = 1;
    public float elevation = 1;
    public float verticalShift = 0;
    public Vector3 offset;

    // Set values using exposed settings
    public void SetComputeValues(ComputeShader cs, PRNG prng, string varSuffix)
    {
        SetComputeValues(cs, prng, varSuffix, scale, elevation, persistence);
    }

    // Set values using custom scale and elevation
    public void SetComputeValues(ComputeShader cs, PRNG prng, string varSuffix, float scale, float elevation)
    {
        SetComputeValues(cs, prng, varSuffix, scale, elevation, persistence);
    }

    // Set values using custom scale and elevation
    public void SetComputeValues(ComputeShader cs, PRNG prng, string varSuffix, float scale, float elevation, float persistence)
    {
        Vector3 seededOffset = new Vector3(prng.Value(), prng.Value(), prng.Value()) * prng.Value() * 10000;

        float[] noiseParams = {
			// [0]
			seededOffset.x + offset.x,
            seededOffset.y + offset.y,
            seededOffset.z + offset.z,
            octaves,
			// [1]
			persistence,
            lacunarity,
            scale,
            elevation,
			// [2]
			verticalShift
        };

        cs.SetFloats("noiseParams" + varSuffix, noiseParams);
    }
}
