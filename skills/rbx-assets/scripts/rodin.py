#!/usr/bin/env python3
"""rbx-assets/scripts/rodin.py "<prompt>" out.glb [--size 2.4]
Drives the blender-mcp addon socket (127.0.0.1:9876): Hyper3D/Rodin text->3D, import, normalise, export GLB.
Blender must be open with the addon enabled. First run: inspect the get_hyper3d_status result by hand.
"""
import json, socket, sys, time

HOST, PORT = "127.0.0.1", 9876

def call(kind, params=None, timeout=120):
    s = socket.create_connection((HOST, PORT), timeout=timeout)
    s.sendall(json.dumps({"type": kind, "params": params or {}}).encode())
    buf = b""
    while True:
        chunk = s.recv(65536)
        if not chunk:
            break
        buf += chunk
        try:
            return json.loads(buf.decode())
        except json.JSONDecodeError:
            continue
    s.close()
    return json.loads(buf.decode())

def main():
    if len(sys.argv) < 3:
        print(__doc__); sys.exit(1)
    prompt, out = sys.argv[1], sys.argv[2]
    size = float(sys.argv[sys.argv.index("--size") + 1]) if "--size" in sys.argv else 2.4
    st = call("get_hyper3d_status")
    print("hyper3d:", json.dumps(st)[:300])
    if st.get("status") != "success" or not st.get("result", {}).get("enabled", True):
        call("execute_code", {"code": "import bpy; bpy.context.scene.blendermcp_use_hyper3d=True; bpy.context.scene.blendermcp_hyper3d_mode='MAIN_SITE'"})
    job = call("create_rodin_job", {"text_prompt": prompt})
    print("job:", json.dumps(job)[:300])
    res = job.get("result", {})
    task_uuid = res.get("uuid") or res.get("task_uuid")
    sub = res.get("jobs", {}).get("subscription_key") or res.get("subscription_key")
    if not task_uuid:
        sys.exit("no task uuid in create_rodin_job result; read the printed job json")
    for _ in range(120):
        time.sleep(5)
        p = call("poll_rodin_job_status", {"subscription_key": sub} if sub else {"request_id": task_uuid})
        stat = json.dumps(p)
        print("poll:", stat[:160])
        if "Done" in stat or "done" in stat.lower():
            break
        if "Failed" in stat:
            sys.exit("rodin failed")
    imp = call("import_generated_asset", {"name": "rodin_asset", "task_uuid": task_uuid})
    print("import:", json.dumps(imp)[:300])
    code = f"""
import bpy, mathutils
objs=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.select_get()] or [o for o in bpy.context.scene.objects if o.type=='MESH']
bpy.ops.object.select_all(action='DESELECT')
for o in objs: o.select_set(True)
bpy.context.view_layer.objects.active=objs[0]
if len(objs)>1: bpy.ops.object.join()
o=bpy.context.view_layer.objects.active
bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY', center='BOUNDS')
o.location=(0,0,0)
d=max(o.dimensions); s={size}/d if d>0 else 1
o.scale=(s,s,s); bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
bpy.ops.object.shade_smooth()
bpy.ops.export_scene.gltf(filepath=r'{out}', export_format='GLB', use_selection=True, export_draco_mesh_compression_enable=True)
print('exported', r'{out}')
"""
    ex = call("execute_code", {"code": code}, timeout=300)
    print("export:", json.dumps(ex)[:300])

if __name__ == "__main__":
    main()
