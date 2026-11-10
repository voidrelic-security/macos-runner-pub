set +e
OUT="${GITHUB_WORKSPACE:-$PWD}/out"; mkdir -p "$OUT"
python3 - <<'PYEOF' > "$OUT/01.txt" 2>&1

import subprocess, os, json, plistlib, glob
OUT=os.environ.get("GITHUB_WORKSPACE",os.getcwd())+"/out"; os.makedirs(OUT,exist_ok=True)
def run(cmd,timeout=180):
    try:
        r=subprocess.run(cmd,capture_output=True,text=True,timeout=timeout)
        return r.returncode,(r.stdout or "")+(r.stderr or "")
    except Exception as e:
        return None,type(e).__name__+": "+str(e)
rows=[]
for p in sorted(glob.glob("/System/Library/LaunchDaemons/*.plist")):
    try:
        d=plistlib.load(open(p,"rb"))
    except Exception:
        continue
    ms=d.get("MachServices") or {}
    if not ms: continue
    user=d.get("UserName","")
    args=d.get("ProgramArguments") or []
    prog=d.get("Program") or (args[0] if args else "")
    label=d.get("Label","")
    rows.append({"label":label,"user":user,"prog":prog,"services":list(ms.keys()),"plist":os.path.basename(p)})
# find which are actually running
rc,o=run(["launchctl","list"],120)
live=set()
for line in o.splitlines()[1:]:
    parts=line.split()
    if len(parts)>=3 and parts[0].isdigit():
        live.add(parts[2])
root_live=[r for r in rows if not r["user"] and r["label"] in live]
print("TOTAL_DAEMONS_WITH_MACH",len(rows),"LIVE_ROOT",len(root_live))
for r in root_live:
    print(f'{r["label"]}\t{r["prog"]}\t{",".join(r["services"])}')
json.dump(root_live,open(OUT+"/root_live.json","w"),indent=1)
print("RESULT live_census_done")

PYEOF
echo "runner_rc=$?" >> "$OUT/01.txt"
