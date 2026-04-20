using System.Collections.Generic;
using System.Diagnostics;
using UnityEngine;

[RequireComponent(typeof(MeshFilter))]
[RequireComponent(typeof(MeshRenderer))]
public class PlanetGenerator : MonoBehaviour
{
    [Header("Generator Settings")]
    public ShapeData shapePreset;
    [SerializeField] private ComputeShader heightMapComputeShader;
    [Tooltip("The vertex count per axis of a face. There are 6 faces and 2 axis per face. As such, the total vertex count after triangulation is [12*resolution^2]")]
    [Range(1,100)]
    [SerializeField] private int meshResolution = 10;
    [Range(1, 1000)]
    public int seed = 100;
    [Range(0.1f, 10)]
    [SerializeField] private float meshScale = 1.0f;

    [Header("Noise Settings")]
    [Tooltip("Perlin noise that generates continents on the planet, used in conjunction with the ocean generation")]
    public SimpleNoiseSettings continentNoise;
    [Tooltip("Perlin noise that goes through a power function to sharpen it, used to generate mountains")]
    public RidgeNoiseSettings ridgeNoise;
    [Tooltip("Perlin noise mask that dictates where the mountains are showing up on the planet")]
    public SimpleNoiseSettings maskNoise;

    [Header("Shader Settings")]
    [SerializeField] private ShaderSettings shaderSettings;

    [Header("Ocean Settings")]
    [SerializeField] private bool hasOcean;
    [Range(0f, 1f)] //Puts the ocean height at Mathf.Lerp(minHeight,maxHeight,oceanlevel)
    [Tooltip("The ratio of how high the ocean is compared to the lowest (0) point on the planet, or the highest (1) point")]
    [SerializeField] private float oceanLevel = 0.2f;
    [SerializeField] private float oceanDepthMultiplier = 5;
    [SerializeField] private float oceanFloorDepth = 1.5f;
    [SerializeField] private float oceanFloorSmoothing = 0.5f;
    [Tooltip("Determines how smoothly the base of mountains blends into the terrain")]
    [SerializeField] private float mountainBlend = 1.2f;
    [SerializeField] private Material oceanMaterial;

    //Components
    private MeshFilter meshFilter;
    private MeshRenderer meshRenderer;
    private Mesh mesh;
    private Material terrainMatInstance;
    private GameObject oceanObject;
    private ComputeBuffer vertexBuffer;
    private ComputeBuffer heightBuffer;

    //Data cache
    static Dictionary<int, SphereGenerator> sphereGenerators;

    //Values
    private Vector2 heightMinMax;
    private void Start()
    {
        Generate();
    }

    public void Generate()
    {
        meshFilter = GetComponent<MeshFilter>();
        meshRenderer = GetComponent<MeshRenderer>();
        Stopwatch stopwatch = Stopwatch.StartNew();
        heightMinMax = GenerateTerrainMesh();
        terrainMatInstance = new Material(shaderSettings.terrainMaterial);
        shaderSettings.SetTerrainProperties(terrainMatInstance, heightMinMax, meshScale, oceanLevel);
        UnityEngine.Debug.Log(heightMinMax);
        meshFilter.mesh = mesh;
        meshRenderer.sharedMaterial = terrainMatInstance;
        if (hasOcean)
        {
            GenerateOcean();
        }
        else
        {
            DestroyImmediate(oceanObject);
        }
            ComputeHelper.Release(vertexBuffer);
        ComputeHelper.Release(heightBuffer);
        shaderSettings.ReleaseBuffers();
    }

    private Vector2 GenerateTerrainMesh()
    {
        (Vector3[] vertices, int[] triangles) = CreateSphereVertsAndTris(meshResolution);
        //Create a compute buffer with every vertex in it.
        ComputeHelper.CreateStructuredBuffer<Vector3>(ref vertexBuffer, vertices);
        float[] heights = CalculateHeights(vertexBuffer);
        float minHeight = float.PositiveInfinity;
        float maxHeight = float.NegativeInfinity;
        for (int i = 0; i < heights.Length; i++)
        {
            float height = heights[i];
            vertices[i] *= height * meshScale;
            minHeight = Mathf.Min(minHeight, height * meshScale);
            maxHeight = Mathf.Max(maxHeight, height * meshScale);
        }
        MeshCreator.CreateMesh(ref mesh, vertices.Length, vertices, triangles);

        Vector4[] shadingData = shaderSettings.GenerateShadingData(vertexBuffer);
        mesh.SetUVs(0, shadingData);

        MeshCreator.GenerateTangents(ref mesh, vertices.Length);

        return new Vector2(minHeight, maxHeight);
    }

    (Vector3[] vertices, int[] triangles) CreateSphereVertsAndTris(int resolution)
    {
        //Cache sphere generator data, so it can reuse existing data when editing values that are not the resolution.
        if (sphereGenerators == null)
        {
            sphereGenerators = new Dictionary<int, SphereGenerator>();
        }
        if (!sphereGenerators.ContainsKey(resolution))
        {
            sphereGenerators.Add(resolution, new SphereGenerator(resolution));
        }
        SphereGenerator generator = sphereGenerators[resolution];

        //Create a duplicate array of the generator's vertices and triangles so they can later be edited without editing the original generator data.
        Vector3[] vertices = new Vector3[generator.vertices.Length];
        int[] triangles = new int[generator.triangles.Length];
        System.Array.Copy(generator.vertices, vertices, vertices.Length);
        System.Array.Copy(generator.triangles, triangles, triangles.Length);
        return (vertices, triangles);
    }

    private float[] CalculateHeights(ComputeBuffer vertexBuffer)
    {
        SetHeightGenerationData(vertexBuffer);
        ComputeHelper.CreateAndSetBuffer<float>(ref heightBuffer, vertexBuffer.count, heightMapComputeShader, "heights");

        //The heightmap compute shader is a simple noise algorithm that gets run on every vertex in the mesh. This is run on the GPU for performance reasons.
        ComputeHelper.Run(heightMapComputeShader, vertexBuffer.count);

        float[] heights = new float[vertexBuffer.count];
        heightBuffer.GetData(heights);
        return heights;
    }
    private void SetHeightGenerationData(ComputeBuffer vertexBuffer)
    {
        PRNG prng = new PRNG(seed);
        continentNoise.SetComputeValues(heightMapComputeShader, prng, "_continents");
        ridgeNoise.SetComputeValues(heightMapComputeShader, prng, "_mountains");
        maskNoise.SetComputeValues(heightMapComputeShader, prng, "_mask");

        heightMapComputeShader.SetFloat("oceanDepthMultiplier", oceanDepthMultiplier);
        heightMapComputeShader.SetFloat("oceanFloorDepth", oceanFloorDepth);
        heightMapComputeShader.SetFloat("oceanFloorSmoothing", oceanFloorSmoothing);
        heightMapComputeShader.SetFloat("mountainBlend", mountainBlend);

        heightMapComputeShader.SetInt("numVertices", vertexBuffer.count);
        heightMapComputeShader.SetBuffer(0, "vertices", vertexBuffer);
    }

    public void LoadShapeData()
    {
        seed = shapePreset.seed;
        continentNoise.octaves = shapePreset.continentNoise.octaves;
        continentNoise.lacunarity = shapePreset.continentNoise.lacunarity;
        continentNoise.persistence = shapePreset.continentNoise.persistence;
        continentNoise.scale = shapePreset.continentNoise.scale;
        continentNoise.elevation = shapePreset.continentNoise.elevation;
        continentNoise.verticalShift = shapePreset.continentNoise.verticalShift;
        continentNoise.offset = shapePreset.continentNoise.offset;

        ridgeNoise.octaves = shapePreset.ridgeNoise.octaves;
        ridgeNoise.lacunarity = shapePreset.ridgeNoise.lacunarity;
        ridgeNoise.persistence = shapePreset.ridgeNoise.persistence;
        ridgeNoise.scale = shapePreset.ridgeNoise.scale;
        ridgeNoise.power = shapePreset.ridgeNoise.power;
        ridgeNoise.elevation = shapePreset.ridgeNoise.elevation;
        ridgeNoise.gain = shapePreset.ridgeNoise.gain;
        ridgeNoise.verticalShift = shapePreset.ridgeNoise.verticalShift;
        ridgeNoise.peakSmoothing = shapePreset.ridgeNoise.peakSmoothing;
        ridgeNoise.offset = shapePreset.ridgeNoise.offset;

        maskNoise.octaves = shapePreset.maskNoise.octaves;
        maskNoise.lacunarity = shapePreset.maskNoise.lacunarity;
        maskNoise.persistence = shapePreset.maskNoise.persistence;
        maskNoise.scale = shapePreset.maskNoise.scale;
        maskNoise.elevation = shapePreset.maskNoise.elevation;
        maskNoise.verticalShift = shapePreset.maskNoise.verticalShift;
        maskNoise.offset = shapePreset.maskNoise.offset;
    }

    private void GenerateOcean()
    {
        if (oceanObject == null)
        {
            oceanObject = GameObject.CreatePrimitive(PrimitiveType.Sphere);
        }
        oceanObject.name = "OceanBody";
        oceanObject.transform.parent = gameObject.transform;
        float scale = Mathf.Lerp(heightMinMax.x, heightMinMax.y, oceanLevel);
        oceanObject.transform.localScale = new Vector3(meshScale * scale + 0.87f, meshScale * scale + 0.87f, meshScale * scale + 0.87f);
        MeshRenderer mr = oceanObject.GetComponent<MeshRenderer>();
        mr.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
        mr.receiveShadows = false;
        mr.sharedMaterial = oceanMaterial;
    }
}
