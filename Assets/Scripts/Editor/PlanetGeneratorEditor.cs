using UnityEditor;
using UnityEngine;

[CustomEditor(typeof(PlanetGenerator))]
public class PlanetGeneratorEditor : Editor
{
    PlanetGenerator generator;

    public override void OnInspectorGUI()
    {
        generator = (PlanetGenerator)target;
        if (GUILayout.Button("Generate new planet..."))
        {
            generator.Generate();
        }
        if (GUILayout.Button("Load Shape Data..."))
        {
            generator.LoadShapeData();
        }
        if (GUILayout.Button("Save Shape Data..."))
        {
            generator.shapePreset.SetData(generator.seed, generator.continentNoise, generator.ridgeNoise, generator.maskNoise);
        }

        DrawDefaultInspector();
    }
}
