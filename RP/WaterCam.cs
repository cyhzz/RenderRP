using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class WaterCam : MonoBehaviour
{
    Camera camera;
    // Start is called before the first frame update
    void Start()
    {
        camera = GetComponent<Camera>();
        camera.depthTextureMode = DepthTextureMode.DepthNormals;
    }
}
