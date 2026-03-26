using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[System.Serializable]
public class RidgeNoiseSettings
{
    [Tooltip("Amount of perlin noise layers")]
    public int octaves = 5;
    [Tooltip("Rate at which the frequency changes with each layer")]
    public float lacunarity = 2;
    [Tooltip("Rate at which the amplitude changes with each layer")]
    public float persistence = 0.5f;
    [Tooltip("Scale of the generated noise map, which essentially scales the initial frequency of the first layer")]
    public float scale = 1;
    [Tooltip("The sharpness of the ridges, using a simple power formula")]
    public float power = 2;
    [Tooltip("Multiplies the resulting noise, unclamped")]
    public float elevation = 1;
    [Tooltip("Multiplies the resulting noise, clamped between values of 0-1. Useful for creating plateaus")]
    public float gain = 1;
    [Tooltip("Is added to the resulting noise to move the ridges up or down linearly")]
    public float verticalShift = 0;
    [Tooltip("How much the peaks are smoothed down to a flatter shape")]
    public float peakSmoothing = 0;
    [Tooltip("The offset at which to sample the noise.")]
    public Vector3 offset;

    // Set values using exposed settings
    public void SetComputeValues(ComputeShader cs, PRNG prng, string varSuffix)
    {
        SetComputeValues(cs, prng, varSuffix, scale, elevation, power);
    }

    // Set values using custom scale and elevation
    public void SetComputeValues(ComputeShader cs, PRNG prng, string varSuffix, float scale, float elevation, float power)
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
			power,
            gain,
            verticalShift,
            peakSmoothing
        };

        cs.SetFloats("noiseParams" + varSuffix, noiseParams);
    }
}