using Unity.VisualScripting;
using UnityEngine;

[CreateAssetMenu(fileName = "ShapeData", menuName = "GeneratorPresets/ShapeData", order = 1)]
public class ShapeData : ScriptableObject
{
    [Range(1, 1000)]
    public int seed = 100;

    [Header("Noise Settings")]
    [Tooltip("Perlin noise that generates continents on the planet, used in conjunction with the ocean generation")]
    public SimpleNoiseSettings continentNoise;
    [Tooltip("Perlin noise that goes through a power function to sharpen it, used to generate mountains")]
    public RidgeNoiseSettings ridgeNoise;
    [Tooltip("Perlin noise mask that dictates where the mountains are showing up on the planet")]
    public SimpleNoiseSettings maskNoise;

    public void GetData(ref int seed, ref SimpleNoiseSettings continentNoise, ref RidgeNoiseSettings ridgeNoise, ref SimpleNoiseSettings maskNoise)
    {
        seed = this.seed;
        continentNoise = this.continentNoise;
        ridgeNoise = this.ridgeNoise;
        maskNoise = this.maskNoise;
    }

    public void SetData(int seed, SimpleNoiseSettings continentNoise, RidgeNoiseSettings ridgeNoise, SimpleNoiseSettings maskNoise)
    {
        this.seed = seed;

        this.continentNoise.octaves = continentNoise.octaves;
        this.continentNoise.lacunarity = continentNoise.lacunarity;
        this.continentNoise.persistence = continentNoise.persistence;
        this.continentNoise.scale = continentNoise.scale;
        this.continentNoise.elevation = continentNoise.elevation;
        this.continentNoise.verticalShift = continentNoise.verticalShift;
        this.continentNoise.offset = continentNoise.offset;

        this.ridgeNoise.octaves = ridgeNoise.octaves;
        this.ridgeNoise.lacunarity = ridgeNoise.lacunarity;
        this.ridgeNoise.persistence = ridgeNoise.persistence;
        this.ridgeNoise.scale = ridgeNoise.scale;
        this.ridgeNoise.power = ridgeNoise.power;
        this.ridgeNoise.elevation = ridgeNoise.elevation;
        this.ridgeNoise.gain = ridgeNoise.gain;
        this.ridgeNoise.verticalShift = ridgeNoise.verticalShift;
        this.ridgeNoise.peakSmoothing = ridgeNoise.peakSmoothing;
        this.ridgeNoise.offset = ridgeNoise.offset;

        this.maskNoise.octaves = maskNoise.octaves;
        this.maskNoise.lacunarity = maskNoise.lacunarity;
        this.maskNoise.persistence = maskNoise.persistence;
        this.maskNoise.scale = maskNoise.scale;
        this.maskNoise.elevation = maskNoise.elevation;
        this.maskNoise.verticalShift = maskNoise.verticalShift;
        this.maskNoise.offset = maskNoise.offset;
    }
}
