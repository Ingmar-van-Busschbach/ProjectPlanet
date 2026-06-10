using UnityEngine;
using UnityEngine.Rendering;

public static class MeshCreator
{
    public static void CreateMesh(ref Mesh mesh, int numVertices, Vector3[] vertices, int[] triangles)
    { // Create new instance of Mesh, with a vertex limit of 65535 for using IndexFormat of Int16, otherwise Int32 will be used. This is for optimization purposes.
        const int vertexLimit16Bit = 1 << 16 - 1; // 65535
        if (mesh == null) { mesh = new Mesh(); }
        else { mesh.Clear(); }
        mesh.indexFormat = (numVertices < vertexLimit16Bit) ? UnityEngine.Rendering.IndexFormat.UInt16 : UnityEngine.Rendering.IndexFormat.UInt32;

        mesh.SetVertices(vertices);
        mesh.SetTriangles(triangles, 0, true);
        mesh.RecalculateNormals();
    }

    public static void GenerateTangents(ref Mesh mesh, int verticeCount)
    {
        // Create crude tangents (vectors perpendicular to surface normal)
        // This is needed (even though normal mapping is being done with triplanar)
        // because surfaceshader wants normals in tangent space
        Vector3[] normals = mesh.normals;
        Vector4[] tangents = new Vector4[mesh.vertices.Length];
        for (int i = 0; i < verticeCount; i++)
        {
            Vector3 normal = normals[i];
            tangents[i] = new Vector4(-normal.z, 0, normal.x, 1);
        }
        mesh.SetTangents(tangents);
    }
}
