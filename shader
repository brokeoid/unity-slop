using UnityEngine;

[System.Serializable]
public class WalkCycleSettings
{
    [Header("Animation Parameters")]
    public int frameCount = 16;
    public float cycleTime = 1.0f;
    public float stepHeight = 0.3f;
    public float stepLength = 0.8f;
    public float bodyBob = 0.1f;
    public float hipSway = 0.05f;
    
    [Header("Performance")]
    public bool useHalfPrecision = true;
    public int textureSize = 512;
}

public class VertexAnimationController : MonoBehaviour
{
    [Header("Setup")]
    public MeshRenderer targetRenderer;
    public MeshFilter targetMeshFilter;
    public WalkCycleSettings walkSettings = new WalkCycleSettings();
    
    [Header("Control")]
    public bool isWalking = false;
    public float walkSpeed = 2f;
    public bool tankControls = true;
    
    private Texture2D animationTexture;
    private Material animationMaterial;
    private Mesh originalMesh;
    private Vector3[] originalVertices;
    private float animationTime;
    
    // Animation data
    private Vector3[,] animationFrames;
    
    void Start()
    {
        SetupComponents();
        GenerateWalkCycle();
        CreateAnimationTexture();
        SetupMaterial();
    }
    
    void Update()
    {
        HandleInput();
        UpdateAnimation();
    }
    
    void SetupComponents()
    {
        if (!targetRenderer) targetRenderer = GetComponent<MeshRenderer>();
        if (!targetMeshFilter) targetMeshFilter = GetComponent<MeshFilter>();
        
        if (!targetMeshFilter || !targetRenderer)
        {
            Debug.LogError("VertexAnimationController needs MeshRenderer and MeshFilter components!");
            return;
        }
        
        originalMesh = targetMeshFilter.sharedMesh;
        Debug.Log($"Original mesh: {originalMesh?.name}, Is null: {originalMesh == null}");
        
        if (originalMesh == null)
        {
            Debug.LogError("MeshFilter has no mesh assigned!");
            return;
        }
        
        originalVertices = originalMesh.vertices;
        Debug.Log($"Mesh has {originalVertices.Length} vertices");
        
        if (originalVertices.Length == 0)
        {
            Debug.LogError("Mesh has 0 vertices! Check if 'Read/Write Enabled' is checked in the model import settings.");
            return;
        }
        
        if (originalVertices.Length > 10000)
        {
            Debug.LogWarning("Consider using a lower poly model for better performance");
        }
    }
    
    void HandleInput()
    {
        float horizontal = Input.GetAxis("Horizontal");
        float vertical = Input.GetAxis("Vertical");
        
        if (tankControls)
        {
            // Tank controls like Resident Evil
            if (Mathf.Abs(vertical) > 0.1f)
            {
                Vector3 movement = transform.forward * vertical * walkSpeed * Time.deltaTime;
                transform.position += movement;
                isWalking = true;
            }
            else
            {
                isWalking = false;
            }
            
            if (Mathf.Abs(horizontal) > 0.1f)
            {
                transform.Rotate(0, horizontal * 90f * Time.deltaTime, 0);
            }
        }
        else
        {
            // Modern movement
            Vector3 input = new Vector3(horizontal, 0, vertical);
            if (input.magnitude > 0.1f)
            {
                Vector3 movement = input.normalized * walkSpeed * Time.deltaTime;
                transform.position += movement;
                transform.rotation = Quaternion.LookRotation(input.normalized);
                isWalking = true;
            }
            else
            {
                isWalking = false;
            }
        }
    }
    
    void UpdateAnimation()
    {
        if (isWalking)
        {
            animationTime += Time.deltaTime / walkSettings.cycleTime;
            if (animationTime > 1f) animationTime -= 1f;
        }
        else
        {
            animationTime = Mathf.Lerp(animationTime, 0f, Time.deltaTime * 2f);
        }
        
        if (animationMaterial)
        {
            animationMaterial.SetFloat("_AnimationTime", animationTime);
            animationMaterial.SetFloat("_IsWalking", isWalking ? 1f : 0f);
        }
    }
    
    void GenerateWalkCycle()
    {
        animationFrames = new Vector3[walkSettings.frameCount, originalVertices.Length];
        
        for (int frame = 0; frame < walkSettings.frameCount; frame++)
        {
            float t = (float)frame / walkSettings.frameCount;
            GenerateFrameVertices(frame, t);
        }
    }
    
    void GenerateFrameVertices(int frameIndex, float normalizedTime)
    {
        for (int i = 0; i < originalVertices.Length; i++)
        {
            Vector3 vertex = originalVertices[i];
            Vector3 animatedVertex = vertex;
            
            float vertexHeight = vertex.y;
            float maxHeight = GetMeshBounds().max.y;
            float minHeight = GetMeshBounds().min.y;
            float heightRatio = (vertexHeight - minHeight) / (maxHeight - minHeight);
            
            if (heightRatio < 0.3f)
            {
                animatedVertex = AnimateLegs(vertex, normalizedTime, vertex.x > 0);
            }
            else if (heightRatio < 0.6f)
            {
                animatedVertex = AnimateHips(vertex, normalizedTime);
            }
            else if (heightRatio < 0.9f)
            {
                animatedVertex = AnimateChest(vertex, normalizedTime);
            }
            
            animationFrames[frameIndex, i] = animatedVertex;
        }
    }
    
    Vector3 AnimateLegs(Vector3 vertex, float t, bool isRightSide)
    {
        Vector3 result = vertex;
        float phase = isRightSide ? t : (t + 0.5f) % 1f;
        
        float stepCycle = Mathf.Sin(phase * Mathf.PI * 2f);
        float liftCycle = Mathf.Max(0, Mathf.Sin(phase * Mathf.PI));
        
        result.z += stepCycle * walkSettings.stepLength * 0.5f;
        result.y += liftCycle * walkSettings.stepHeight;
        
        return result;
    }
    
    Vector3 AnimateHips(Vector3 vertex, float t)
    {
        Vector3 result = vertex;
        result.x += Mathf.Sin(t * Mathf.PI * 2f) * walkSettings.hipSway;
        result.y += Mathf.Sin(t * Mathf.PI * 4f) * walkSettings.bodyBob * 0.5f;
        return result;
    }
    
    Vector3 AnimateChest(Vector3 vertex, float t)
    {
        Vector3 result = vertex;
        result.x -= Mathf.Sin(t * Mathf.PI * 2f) * walkSettings.hipSway * 0.3f;
        result.y += Mathf.Sin(t * Mathf.PI * 4f) * walkSettings.bodyBob * 0.3f;
        return result;
    }
    
    void CreateAnimationTexture()
    {
        int texWidth = walkSettings.textureSize;
        int texHeight = Mathf.CeilToInt((float)(originalVertices.Length * 3) / texWidth);
        
        TextureFormat format = walkSettings.useHalfPrecision ? TextureFormat.RGBAHalf : TextureFormat.RGBAFloat;
        animationTexture = new Texture2D(texWidth, texHeight * walkSettings.frameCount, format, false);
        animationTexture.filterMode = FilterMode.Point;
        animationTexture.wrapMode = TextureWrapMode.Clamp;
        
        Color[] pixels = new Color[texWidth * texHeight * walkSettings.frameCount];
        
        for (int frame = 0; frame < walkSettings.frameCount; frame++)
        {
            for (int vertex = 0; vertex < originalVertices.Length; vertex++)
            {
                Vector3 animVertex = animationFrames[frame, vertex];
                Vector3 offset = animVertex - originalVertices[vertex];
                
                int pixelIndex = frame * texWidth * texHeight + vertex;
                if (pixelIndex < pixels.Length)
                {
                    pixels[pixelIndex] = new Color(offset.x, offset.y, offset.z, 1f);
                }
            }
        }
        
        animationTexture.SetPixels(pixels);
        animationTexture.Apply();
        
        Debug.Log($"Created animation texture: {texWidth}x{texHeight * walkSettings.frameCount}");
    }
    
    void SetupMaterial()
    {
        Shader shader = Shader.Find("Custom/HDRP_VertexAnimation");
        
        if (shader == null)
        {
            Debug.LogError("Could not find shader 'Custom/HDRP_VertexAnimation'! Make sure the shader file is in your project.");
            return;
        }
        
        animationMaterial = new Material(shader);
        Debug.Log($"Shader being used: {animationMaterial.shader.name}");
        
        animationMaterial.SetTexture("_AnimationTexture", animationTexture);
        animationMaterial.SetInt("_AnimFrameCount", walkSettings.frameCount);
        animationMaterial.SetInt("_VertexCount", originalVertices.Length);
        animationMaterial.SetInt("_TextureWidth", walkSettings.textureSize);
        
        targetRenderer.material = animationMaterial;
    }
    
    Bounds GetMeshBounds()
    {
        if (originalMesh) return originalMesh.bounds;
        
        Vector3 min = originalVertices[0];
        Vector3 max = originalVertices[0];
        
        for (int i = 1; i < originalVertices.Length; i++)
        {
            min = Vector3.Min(min, originalVertices[i]);
            max = Vector3.Max(max, originalVertices[i]);
        }
        
        return new Bounds((min + max) * 0.5f, max - min);
    }
    
    void OnDestroy()
    {
        if (animationTexture) DestroyImmediate(animationTexture);
        if (animationMaterial) DestroyImmediate(animationMaterial);
    }
}
