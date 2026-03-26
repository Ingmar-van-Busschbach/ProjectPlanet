using System.Collections.Generic;
using UnityEngine;

public class SphereGenerator
{
    public readonly Vector3[] vertices;
    public readonly int[] triangles;
    public readonly int resolution;

    // Internal:
    private FixedSizeList<Vector3> currentVertices;
    private FixedSizeList<int> currentTriangles;
    private int numDivisions;
    private int numVertsPerFace;

    // Indices of the vertex pairs that make up each of the initial 12 edges
    static readonly int[] vertexPairs = { 0, 1, 0, 2, 0, 3, 0, 4, 1, 2, 2, 3, 3, 4, 4, 1, 5, 1, 5, 2, 5, 3, 5, 4 };
    // Indices of the edge triplets that make up the initial 8 faces
    static readonly int[] edgeTriplets = { 0, 1, 4, 1, 2, 5, 2, 3, 6, 3, 0, 7, 8, 9, 4, 9, 10, 5, 10, 11, 6, 11, 8, 7 };
    // The six initial vertices
    static readonly Vector3[] baseVertices = { Vector3.up, Vector3.left, Vector3.back, Vector3.right, Vector3.forward, Vector3.down };

    public SphereGenerator(int resolution)
    {
        this.resolution = resolution;

        //Calculate vertex and triangle count for the unit sphere
        numDivisions = Mathf.Max(0, resolution);
        numVertsPerFace = ((numDivisions + 3) * (numDivisions + 3) - (numDivisions + 3)) / 2;
        int numVerts = numVertsPerFace * 8 - (numDivisions + 2) * 12 + 6;
        int numTrisPerFace = (numDivisions + 1) * (numDivisions + 1);

        //Create lists for the vertices and triangles to be generated.
        currentVertices = new FixedSizeList<Vector3>(numVerts);
        currentVertices.AddRange(baseVertices);
        currentTriangles = new FixedSizeList<int>(numTrisPerFace * 8 * 3);

        // Create 12 edges, with n vertices added along them (n = numDivisions)

        //Create 12 edges of a square
        Edge[] edges = new Edge[12];

        //For each edge
        for (int i = 0; i < vertexPairs.Length; i += 2)
        {
            //Select the start and end position of the square edge
            Vector3 startVertex = currentVertices.items[vertexPairs[i]];
            Vector3 endVertex = currentVertices.items[vertexPairs[i + 1]];

            //Create indexes for all vertexes along the edge and select the starting corner vertex
            int[] edgeVertexIndices = new int[numDivisions + 2];
            edgeVertexIndices[0] = vertexPairs[i];

            // Add vertices along edge
            for (int divisionIndex = 0; divisionIndex < numDivisions; divisionIndex++)
            {
                float t = (divisionIndex + 1f) / (numDivisions + 1f);
                //Register current vertex index
                edgeVertexIndices[divisionIndex + 1] = currentVertices.nextIndex;
                //Lerp between the starting and ending corners of the edge to generate the vertices there, creating a circle thanks to spherical lerp
                currentVertices.Add(Vector3.Slerp(startVertex, endVertex, t));
            }
            //Set final corner vertex index
            edgeVertexIndices[numDivisions + 1] = vertexPairs[i + 1];
            int edgeIndex = i / 2;
            edges[edgeIndex] = new Edge(edgeVertexIndices);
        }

        // Create faces
        for (int i = 0; i < edgeTriplets.Length; i += 3)
        {
            int faceIndex = i / 3;
            bool reverse = faceIndex > 3;
            CreateFace(edges[edgeTriplets[i]], edges[edgeTriplets[i + 1]], edges[edgeTriplets[i + 2]], reverse);
        }

        vertices = currentVertices.items;
        triangles = currentTriangles.items;
    }

    void CreateFace(Edge sideA, Edge sideB, Edge bottom, bool reverse)
    {
        int numPointsInEdge = sideA.vertexIndices.Length;
        FixedSizeList<int> vertexMap = new FixedSizeList<int>(numVertsPerFace);
        vertexMap.Add(sideA.vertexIndices[0]); // top of triangle

        //For each vertex along side A
        for (int i = 1; i < numPointsInEdge - 1; i++)
        {
            // Side A starting vertex
            vertexMap.Add(sideA.vertexIndices[i]);

            // Add vertices between sideA and sideB
            Vector3 sideAVertex = currentVertices.items[sideA.vertexIndices[i]];
            Vector3 sideBVertex = currentVertices.items[sideB.vertexIndices[i]];

            // Add points between the Side A vertex and Side B vertex to maintain evenly sized vertex spacing
            int numInnerPoints = i - 1;
            for (int j = 0; j < numInnerPoints; j++)
            {
                float t = (j + 1f) / (numInnerPoints + 1f); //Add 1 to not divide by 0
                vertexMap.Add(currentVertices.nextIndex);
                currentVertices.Add(Vector3.Slerp(sideAVertex, sideBVertex, t));
            }

            // Side B ending vertex
            vertexMap.Add(sideB.vertexIndices[i]);
        }

        // Add bottom edge vertices
        for (int i = 0; i < numPointsInEdge; i++)
        {
            vertexMap.Add(bottom.vertexIndices[i]);
        }

        // Triangulate
        int numRows = numDivisions + 1;
        for (int row = 0; row < numRows; row++)
        {
            // vertices down left edge follow quadratic sequence: 0, 1, 3, 6, 10, 15...
            // the nth term can be calculated with: (n^2 - n)/2
            int topVertex = ((row + 1) * (row + 1) - row - 1) / 2;
            int bottomVertex = ((row + 2) * (row + 2) - row - 2) / 2;

            int numTrianglesInRow = 1 + 2 * row;
            for (int column = 0; column < numTrianglesInRow; column++)
            {
                int v0, v1, v2;


                //Select upwards or downwards facing triangle
                if (column % 2 == 0)
                {
                    v0 = topVertex;
                    v1 = bottomVertex + 1;
                    v2 = bottomVertex;
                    topVertex++;
                    bottomVertex++;
                }
                else
                {
                    v0 = topVertex;
                    v1 = bottomVertex;
                    v2 = topVertex - 1;
                }

                currentTriangles.Add(vertexMap.items[v0]);
                currentTriangles.Add(vertexMap.items[(reverse) ? v2 : v1]);
                currentTriangles.Add(vertexMap.items[(reverse) ? v1 : v2]);
            }
        }
    }
}
