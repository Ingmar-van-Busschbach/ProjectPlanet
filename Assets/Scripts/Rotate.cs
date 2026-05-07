using UnityEngine;

public class Rotate : MonoBehaviour
{
    [SerializeField] private float rotationSpeed;
    void Update()
    {
        Vector3 rotation = transform.rotation.eulerAngles;
        rotation += new Vector3(0, rotationSpeed * Time.deltaTime, 0);
        transform.rotation = Quaternion.Euler(rotation);
    }
}
