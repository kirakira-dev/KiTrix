using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Globalization;
using System.Linq;
using BfresLibrary;
using BfresLibrary.Helpers;
using BfresLibrary.Switch;
using BCnEncoder.Decoder;
using BCnEncoder.Shared;
using SkiaSharp;

class Program
{
    static void Main(string[] args)
    {
        if (args.Length < 2)
        {
            Console.WriteLine("Usage: Bfres2Obj <input.bfres[.zs]> <output_dir> [--dae]");
            Console.WriteLine("  Output: <output_dir>/<name>.obj + .mtl + textures/");
            Console.WriteLine("  --dae: Export COLLADA with skeleton/skinning instead of OBJ");
            return;
        }
        bool exportDae = args.Any(a => a == "--dae");

        byte[] data = File.ReadAllBytes(args[0]);
        if (data.Length >= 4 && data[0] == 0x28 && data[1] == 0xB5 && data[2] == 0x2F && data[3] == 0xFD)
        {
            Console.WriteLine("Decompressing zstd...");
            using var dec = new ZstdSharp.Decompressor();
            data = dec.Unwrap(data).ToArray();
        }

        ResFile bfres;
        using (var ms = new MemoryStream(data))
            bfres = new ResFile(ms);

        string baseName = Path.GetFileNameWithoutExtension(Path.GetFileNameWithoutExtension(args[0]));
        baseName = baseName.Replace("Fld_", "Vss_");
        string outDir = args[1];
        string stageDir = Path.Combine(outDir, baseName);
        string texDir = Path.Combine(stageDir, "textures");
        Directory.CreateDirectory(texDir);

        Console.WriteLine($"Models: {bfres.Models.Count}, Textures: {bfres.Textures.Count}, ExternalFiles: {bfres.ExternalFiles.Count}");

        // Load textures from embedded BNTX in ExternalFiles
        var exportedTextures = new HashSet<string>();

        // First try direct Textures dict
        foreach (var tKv in bfres.Textures)
        {
            ExportTexture(tKv.Key, tKv.Value as SwitchTexture, texDir, exportedTextures);
        }

        // Then try ExternalFiles for embedded BNTX
        foreach (var efKv in bfres.ExternalFiles)
        {
            Console.WriteLine($"  ExternalFile: {efKv.Key} ({efKv.Value.Data?.Length ?? 0} bytes)");
            if (efKv.Value.Data != null && efKv.Value.Data.Length > 4)
            {
                // Check for BNTX magic
                byte[] efData = efKv.Value.Data;
                if (efData[0] == (byte)'B' && efData[1] == (byte)'N' && efData[2] == (byte)'T' && efData[3] == (byte)'X')
                {
                    Console.WriteLine($"    Found BNTX archive!");
                    try
                    {
                        var bntx = new Syroot.NintenTools.NSW.Bntx.BntxFile(new MemoryStream(efData));
                        Console.WriteLine($"    BNTX textures: {bntx.Textures.Count}");
                        foreach (var tex in bntx.Textures)
                        {
                            string texName = tex.Name;
                            try
                            {
                                int w = (int)tex.Width;
                                int h = (int)tex.Height;
                                var format = tex.Format;

                                // Get deswizzled data via BfresLibrary's TegraX1Swizzle
                                byte[] combined = tex.TextureData[0].SelectMany(x => x).ToArray();
                                byte[] deswizzled = BfresLibrary.Swizzling.TegraX1Swizzle.GetImageData(
                                    tex, combined, 0, 0, 0,
                                    tex.BlockHeightLog2, 1,
                                    tex.TileMode == Syroot.NintenTools.NSW.Bntx.GFX.TileMode.LinearAligned);

                                byte[]? rgba = DecodeToRGBA(deswizzled, w, h, format);
                                if (rgba == null) continue;

                                string pngPath = Path.Combine(texDir, texName + ".png");
                                SavePNG(rgba, w, h, pngPath);
                                exportedTextures.Add(texName);
                            }
                            catch (Exception ex)
                            {
                                Console.WriteLine($"    Texture '{texName}' failed: {ex.Message}");
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        Console.WriteLine($"    BNTX load failed: {ex.Message}");
                    }
                }
            }
        }
        Console.WriteLine($"Exported {exportedTextures.Count} textures");

        if (exportDae)
        {
            DaeExporter.Export(bfres, stageDir, baseName, exportedTextures);
            return;
        }

        // Generate MTL
        var mtlSb = new StringBuilder();
        mtlSb.AppendLine("# KiTrix material file");
        var materialTexMap = new Dictionary<string, string>();

        foreach (var mKv in bfres.Models)
        {
            foreach (var matKv in mKv.Value.Materials)
            {
                string matName = $"{mKv.Key}_{matKv.Key}";
                mtlSb.AppendLine($"newmtl {matName}");
                mtlSb.AppendLine("Ka 1.0 1.0 1.0");
                mtlSb.AppendLine("Kd 1.0 1.0 1.0");
                mtlSb.AppendLine("Ks 0.1 0.1 0.1");
                mtlSb.AppendLine("Ns 32.0");
                mtlSb.AppendLine("d 1.0");

                var mat = matKv.Value;
                if (mat.TextureRefs != null && mat.TextureRefs.Count > 0)
                {
                    string? diffuseTex = null;
                    string? normalTex = null;
                    foreach (var texRef in mat.TextureRefs)
                    {
                        string n = texRef.Name;
                        if (n.EndsWith("_Alb") && exportedTextures.Contains(n))
                            diffuseTex = n;
                        else if (n.EndsWith("_Nrm") && exportedTextures.Contains(n))
                            normalTex = n;
                    }
                    if (diffuseTex == null)
                    {
                        foreach (var texRef in mat.TextureRefs)
                        {
                            if (exportedTextures.Contains(texRef.Name) && !texRef.Name.Contains("BakeDummy"))
                            { diffuseTex = texRef.Name; break; }
                        }
                    }
                    if (diffuseTex == null && exportedTextures.Contains(mat.TextureRefs[0].Name))
                        diffuseTex = mat.TextureRefs[0].Name;

                    if (diffuseTex != null)
                    {
                        mtlSb.AppendLine($"map_Kd textures/{diffuseTex}.png");
                        materialTexMap[matName] = diffuseTex;
                    }
                    if (normalTex != null)
                        mtlSb.AppendLine($"map_bump textures/{normalTex}.png");
                }
                mtlSb.AppendLine();
            }
        }

        string mtlPath = Path.Combine(stageDir, baseName + ".mtl");
        File.WriteAllText(mtlPath, mtlSb.ToString());

        // Generate OBJ with UVs and materials
        var objSb = new StringBuilder();
        objSb.AppendLine("# KiTrix Bfres2Obj (textured)");
        objSb.AppendLine($"mtllib {baseName}.mtl");
        int vOff = 1, nOff = 1, tOff = 1;

        foreach (var mKv in bfres.Models)
        {
            Model model = mKv.Value;
            Console.WriteLine($"  {mKv.Key}: {model.Shapes.Count} shapes, bones: {model.Skeleton?.Bones?.Count ?? 0}");

            var worldTransforms = new Dictionary<int, float[]>();
            if (model.Skeleton != null && model.Skeleton.Bones != null)
            {
                var bones = model.Skeleton.Bones;
                for (int bi = 0; bi < bones.Count; bi++)
                {
                    var bone = bones[bi];
                    float tx = bone.Position.X, ty = bone.Position.Y, tz = bone.Position.Z;
                    float rx = bone.Rotation.X, ry = bone.Rotation.Y, rz = bone.Rotation.Z, rw = bone.Rotation.W;
                    float sx = bone.Scale.X, sy = bone.Scale.Y, sz = bone.Scale.Z;

                    float[] local = QuatToMatrix(tx, ty, tz, rx, ry, rz, rw, sx, sy, sz);
                    if (bone.ParentIndex >= 0 && worldTransforms.ContainsKey(bone.ParentIndex))
                        local = Multiply4x4(worldTransforms[bone.ParentIndex], local);
                    worldTransforms[bi] = local;

                    bool isIdentity = Math.Abs(tx) < 0.001f && Math.Abs(ty) < 0.001f && Math.Abs(tz) < 0.001f;
                    if (!isIdentity && bi < 20)
                        Console.WriteLine($"    Bone[{bi}] '{bone.Name}' pos=({tx:F2},{ty:F2},{tz:F2}) parent={bone.ParentIndex}");
                }
            }

            foreach (var sKv in model.Shapes)
            {
                Shape shape = sKv.Value;
                string objName = $"{mKv.Key}_{sKv.Key}";
                objSb.AppendLine($"o {objName}");

                int boneIdx = shape.BoneIndex;
                float[]? boneMtx = null;
                if (boneIdx >= 0 && worldTransforms.ContainsKey(boneIdx))
                {
                    var m = worldTransforms[boneIdx];
                    bool isIdentity = Math.Abs(m[12]) < 0.001f && Math.Abs(m[13]) < 0.001f && Math.Abs(m[14]) < 0.001f
                        && Math.Abs(m[0] - 1) < 0.001f && Math.Abs(m[5] - 1) < 0.001f && Math.Abs(m[10] - 1) < 0.001f;
                    if (!isIdentity) boneMtx = m;
                }

                // Material
                if (shape.MaterialIndex < model.Materials.Count)
                {
                    var matKeys = model.Materials.Keys.ToList();
                    string matName = $"{mKv.Key}_{matKeys[shape.MaterialIndex]}";
                    objSb.AppendLine($"usemtl {matName}");
                }

                VertexBuffer vtxBuf = model.VertexBuffers[shape.VertexBufferIndex];
                var helper = new VertexBufferHelper(vtxBuf, bfres.ByteOrder);

                float[]? pos = null, nrm = null, uv = null;
                int vc = 0;
                bool hasUV = false;

                foreach (var attr in helper.Attributes)
                {
                    if (attr.Name == "_p0")
                    {
                        vc = attr.Data.Length;
                        pos = new float[vc * 3];
                        for (int i = 0; i < vc; i++)
                        { pos[i*3] = attr.Data[i].X; pos[i*3+1] = attr.Data[i].Y; pos[i*3+2] = attr.Data[i].Z; }
                    }
                    else if (attr.Name == "_n0")
                    {
                        nrm = new float[attr.Data.Length * 3];
                        for (int i = 0; i < attr.Data.Length; i++)
                        { nrm[i*3] = attr.Data[i].X; nrm[i*3+1] = attr.Data[i].Y; nrm[i*3+2] = attr.Data[i].Z; }
                    }
                    else if (attr.Name == "_u0")
                    {
                        hasUV = true;
                        uv = new float[attr.Data.Length * 2];
                        for (int i = 0; i < attr.Data.Length; i++)
                        { uv[i*2] = attr.Data[i].X; uv[i*2+1] = 1.0f - attr.Data[i].Y; }
                    }
                }

                if (pos == null || vc == 0) continue;

                if (boneMtx != null)
                {
                    for (int i = 0; i < vc; i++)
                    {
                        float x = pos[i*3], y = pos[i*3+1], z = pos[i*3+2];
                        pos[i*3]   = boneMtx[0]*x + boneMtx[4]*y + boneMtx[8]*z  + boneMtx[12];
                        pos[i*3+1] = boneMtx[1]*x + boneMtx[5]*y + boneMtx[9]*z  + boneMtx[13];
                        pos[i*3+2] = boneMtx[2]*x + boneMtx[6]*y + boneMtx[10]*z + boneMtx[14];
                    }
                    if (nrm != null)
                    {
                        for (int i = 0; i < vc; i++)
                        {
                            float x = nrm[i*3], y = nrm[i*3+1], z = nrm[i*3+2];
                            nrm[i*3]   = boneMtx[0]*x + boneMtx[4]*y + boneMtx[8]*z;
                            nrm[i*3+1] = boneMtx[1]*x + boneMtx[5]*y + boneMtx[9]*z;
                            nrm[i*3+2] = boneMtx[2]*x + boneMtx[6]*y + boneMtx[10]*z;
                        }
                    }
                }

                for (int i = 0; i < vc; i++)
                    objSb.AppendLine(string.Format(CultureInfo.InvariantCulture, "v {0:F4} {1:F4} {2:F4}", pos[i*3], pos[i*3+1], pos[i*3+2]));

                if (nrm != null)
                    for (int i = 0; i < vc; i++)
                        objSb.AppendLine(string.Format(CultureInfo.InvariantCulture, "vn {0:F4} {1:F4} {2:F4}", nrm[i*3], nrm[i*3+1], nrm[i*3+2]));

                if (uv != null)
                    for (int i = 0; i < vc; i++)
                        objSb.AppendLine(string.Format(CultureInfo.InvariantCulture, "vt {0:F6} {1:F6}", uv[i*2], uv[i*2+1]));

                if (shape.Meshes.Count > 0)
                {
                    var mesh = shape.Meshes[0];
                    uint[] idx = mesh.GetIndices().ToArray();
                    for (int i = 0; i + 2 < idx.Length; i += 3)
                    {
                        int a = (int)(idx[i] + mesh.FirstVertex);
                        int b = (int)(idx[i+1] + mesh.FirstVertex);
                        int c = (int)(idx[i+2] + mesh.FirstVertex);
                        if (hasUV && nrm != null)
                            objSb.AppendLine($"f {a+vOff}/{a+tOff}/{a+nOff} {b+vOff}/{b+tOff}/{b+nOff} {c+vOff}/{c+tOff}/{c+nOff}");
                        else if (nrm != null)
                            objSb.AppendLine($"f {a+vOff}//{a+nOff} {b+vOff}//{b+nOff} {c+vOff}//{c+nOff}");
                        else
                            objSb.AppendLine($"f {a+vOff} {b+vOff} {c+vOff}");
                    }
                }
                vOff += vc;
                nOff += vc;
                if (hasUV) tOff += vc;
            }
        }

        string objPath = Path.Combine(stageDir, baseName + ".obj");
        File.WriteAllText(objPath, objSb.ToString());
        Console.WriteLine($"-> {objPath} ({new FileInfo(objPath).Length/1024} KB)");
    }

    static void ExportTexture(string texName, SwitchTexture? tex, string texDir, HashSet<string> exported)
    {
        if (tex == null) return;
        try
        {
            byte[] deswizzled = tex.GetDeswizzledData(0, 0);
            int w = (int)tex.Width;
            int h = (int)tex.Height;
            var format = tex.Texture.Format;
            byte[]? rgba = DecodeToRGBA(deswizzled, w, h, format);
            if (rgba == null) return;
            SavePNG(rgba, w, h, Path.Combine(texDir, texName + ".png"));
            exported.Add(texName);
        }
        catch (Exception ex)
        {
            Console.WriteLine($"  Texture '{texName}' failed: {ex.Message}");
        }
    }

    static byte[]? DecodeToRGBA(byte[] compressed, int width, int height, Syroot.NintenTools.NSW.Bntx.GFX.SurfaceFormat format)
    {
        var decoder = new BcDecoder();
        int blockW = 4, blockH = 4;
        int blocksX = (width + blockW - 1) / blockW;
        int blocksY = (height + blockH - 1) / blockH;

        CompressionFormat bcFormat;
        switch (format)
        {
            case Syroot.NintenTools.NSW.Bntx.GFX.SurfaceFormat.BC1_UNORM:
            case Syroot.NintenTools.NSW.Bntx.GFX.SurfaceFormat.BC1_SRGB:
                bcFormat = CompressionFormat.Bc1; break;
            case Syroot.NintenTools.NSW.Bntx.GFX.SurfaceFormat.BC2_UNORM:
            case Syroot.NintenTools.NSW.Bntx.GFX.SurfaceFormat.BC2_SRGB:
                bcFormat = CompressionFormat.Bc2; break;
            case Syroot.NintenTools.NSW.Bntx.GFX.SurfaceFormat.BC3_UNORM:
            case Syroot.NintenTools.NSW.Bntx.GFX.SurfaceFormat.BC3_SRGB:
                bcFormat = CompressionFormat.Bc3; break;
            case Syroot.NintenTools.NSW.Bntx.GFX.SurfaceFormat.BC4_UNORM:
            case Syroot.NintenTools.NSW.Bntx.GFX.SurfaceFormat.BC4_SNORM:
                bcFormat = CompressionFormat.Bc4; break;
            case Syroot.NintenTools.NSW.Bntx.GFX.SurfaceFormat.BC5_UNORM:
            case Syroot.NintenTools.NSW.Bntx.GFX.SurfaceFormat.BC5_SNORM:
                bcFormat = CompressionFormat.Bc5; break;
            case Syroot.NintenTools.NSW.Bntx.GFX.SurfaceFormat.BC7_UNORM:
            case Syroot.NintenTools.NSW.Bntx.GFX.SurfaceFormat.BC7_SRGB:
                bcFormat = CompressionFormat.Bc7; break;
            case Syroot.NintenTools.NSW.Bntx.GFX.SurfaceFormat.R8_G8_B8_A8_UNORM:
            case Syroot.NintenTools.NSW.Bntx.GFX.SurfaceFormat.R8_G8_B8_A8_SRGB:
                return compressed;
            default:
                Console.WriteLine($"    Unsupported format: {format}");
                return null;
        }

        try
        {
            var pixels = decoder.DecodeRaw(compressed, width, height, bcFormat);
            byte[] rgba = new byte[width * height * 4];
            for (int i = 0; i < width * height && i < pixels.Length; i++)
            {
                rgba[i * 4 + 0] = pixels[i].r;
                rgba[i * 4 + 1] = pixels[i].g;
                rgba[i * 4 + 2] = pixels[i].b;
                rgba[i * 4 + 3] = pixels[i].a;
            }
            return rgba;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"    BC decode error: {ex.Message}");
            return null;
        }
    }

    static void SavePNG(byte[] rgba, int width, int height, string path)
    {
        using var bitmap = new SKBitmap(width, height, SKColorType.Rgba8888, SKAlphaType.Unpremul);
        var handle = System.Runtime.InteropServices.GCHandle.Alloc(rgba, System.Runtime.InteropServices.GCHandleType.Pinned);
        try
        {
            bitmap.InstallPixels(new SKImageInfo(width, height, SKColorType.Rgba8888, SKAlphaType.Unpremul),
                handle.AddrOfPinnedObject(), width * 4);
            using var image = SKImage.FromBitmap(bitmap);
            using var encodedData = image.Encode(SKEncodedImageFormat.Png, 90);
            using var stream = File.OpenWrite(path);
            encodedData.SaveTo(stream);
        }
        finally
        {
            handle.Free();
        }
    }

    static float[] QuatToMatrix(float tx, float ty, float tz, float rx, float ry, float rz, float rw, float sx, float sy, float sz)
    {
        float x2 = rx+rx, y2 = ry+ry, z2 = rz+rz;
        float xx = rx*x2, xy = rx*y2, xz = rx*z2;
        float yy = ry*y2, yz = ry*z2, zz = rz*z2;
        float wx = rw*x2, wy = rw*y2, wz = rw*z2;
        return new float[] {
            (1-(yy+zz))*sx, (xy+wz)*sx,     (xz-wy)*sx,     0,
            (xy-wz)*sy,     (1-(xx+zz))*sy,  (yz+wx)*sy,     0,
            (xz+wy)*sz,     (yz-wx)*sz,      (1-(xx+yy))*sz, 0,
            tx,              ty,              tz,              1
        };
    }

    static float[] Multiply4x4(float[] a, float[] b)
    {
        float[] r = new float[16];
        for (int row = 0; row < 4; row++)
            for (int col = 0; col < 4; col++)
                r[col*4+row] = a[row]*b[col*4] + a[4+row]*b[col*4+1] + a[8+row]*b[col*4+2] + a[12+row]*b[col*4+3];
        return r;
    }
}
