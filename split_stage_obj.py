#!/usr/bin/env python3
"""Split a large OBJ into per-material-group sub-OBJs for SceneKit compatibility."""
import sys, os, time

def split_obj(obj_path):
    t0 = time.time()
    obj_dir = os.path.dirname(obj_path)
    base = os.path.splitext(os.path.basename(obj_path))[0]
    out_dir = os.path.join(obj_dir, f"{base}_parts")
    os.makedirs(out_dir, exist_ok=True)

    # Symlink textures dir
    tex_src = os.path.join(obj_dir, "textures")
    tex_dst = os.path.join(out_dir, "textures")
    if os.path.isdir(tex_src) and not os.path.exists(tex_dst):
        os.symlink(tex_src, tex_dst)

    # Copy MTL
    mtl_name = None
    with open(obj_path) as f:
        for line in f:
            if line.startswith("mtllib "):
                mtl_name = line.strip().split(" ", 1)[1]
                break

    if mtl_name:
        mtl_src = os.path.join(obj_dir, mtl_name)
        mtl_dst = os.path.join(out_dir, mtl_name)
        if os.path.exists(mtl_src) and not os.path.exists(mtl_dst):
            import shutil
            shutil.copy2(mtl_src, mtl_dst)

    # Parse OBJ
    verts = []
    vts = []
    vns = []
    groups = []  # [(mat_name, faces)]
    current_mat = "default"
    current_faces = []

    with open(obj_path) as f:
        for line in f:
            if line.startswith("v "):
                verts.append(line)
            elif line.startswith("vt "):
                vts.append(line)
            elif line.startswith("vn "):
                vns.append(line)
            elif line.startswith("usemtl "):
                if current_faces:
                    groups.append((current_mat, current_faces))
                current_mat = line.strip().split(" ", 1)[1]
                current_faces = []
            elif line.startswith("f "):
                current_faces.append(line)
    if current_faces:
        groups.append((current_mat, current_faces))

    print(f"Parsed: {len(verts)} verts, {len(vts)} vts, {len(vns)} vns, {len(groups)} material groups")

    # Batch groups into chunks of ~30 for GPU material limit
    BATCH = 30
    part_files = []

    for batch_idx in range(0, len(groups), BATCH):
        batch = groups[batch_idx:batch_idx + BATCH]
        part_name = f"part_{batch_idx:04d}.obj"
        part_path = os.path.join(out_dir, part_name)

        # Collect all vertex indices used in this batch
        v_used = set()
        vt_used = set()
        vn_used = set()
        for _, faces in batch:
            for face in faces:
                for vert in face.strip().split()[1:]:
                    parts = vert.split("/")
                    if len(parts) >= 1 and parts[0]: v_used.add(int(parts[0]))
                    if len(parts) >= 2 and parts[1]: vt_used.add(int(parts[1]))
                    if len(parts) >= 3 and parts[2]: vn_used.add(int(parts[2]))

        # Create remapping
        v_list = sorted(v_used)
        vt_list = sorted(vt_used)
        vn_list = sorted(vn_used)
        v_map = {old: new + 1 for new, old in enumerate(v_list)}
        vt_map = {old: new + 1 for new, old in enumerate(vt_list)}
        vn_map = {old: new + 1 for new, old in enumerate(vn_list)}

        with open(part_path, "w") as f:
            if mtl_name:
                f.write(f"mtllib {mtl_name}\n")
            for idx in v_list:
                f.write(verts[idx - 1])
            for idx in vt_list:
                f.write(vts[idx - 1])
            for idx in vn_list:
                f.write(vns[idx - 1])

            for mat_name, faces in batch:
                f.write(f"usemtl {mat_name}\n")
                for face in faces:
                    tokens = face.strip().split()
                    new_tokens = ["f"]
                    for vert in tokens[1:]:
                        parts = vert.split("/")
                        new_parts = []
                        if len(parts) >= 1 and parts[0]:
                            new_parts.append(str(v_map[int(parts[0])]))
                        else:
                            new_parts.append("")
                        if len(parts) >= 2 and parts[1]:
                            new_parts.append(str(vt_map[int(parts[1])]))
                        elif len(parts) >= 2:
                            new_parts.append("")
                        if len(parts) >= 3 and parts[2]:
                            new_parts.append(str(vn_map[int(parts[2])]))
                        new_tokens.append("/".join(new_parts))
                    f.write(" ".join(new_tokens) + "\n")

        part_files.append(part_name)

    # Write manifest
    with open(os.path.join(out_dir, "manifest.txt"), "w") as f:
        for p in part_files:
            f.write(p + "\n")

    print(f"Split into {len(part_files)} part files in {out_dir}")
    print(f"Time: {time.time() - t0:.1f}s")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        # Process all stages
        stages_dir = os.path.expanduser("~/Dev/KiTrix/stages")
        for d in sorted(os.listdir(stages_dir)):
            obj = os.path.join(stages_dir, d, f"{d}.obj")
            if os.path.exists(obj):
                parts_dir = os.path.join(stages_dir, d, f"{d}_parts")
                if os.path.isdir(parts_dir):
                    print(f"Skipping {d} (already split)")
                    continue
                print(f"\n=== Splitting {d} ===")
                split_obj(obj)
    else:
        split_obj(sys.argv[1])
