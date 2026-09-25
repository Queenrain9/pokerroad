#!/usr/bin/env python3
"""Reconstruct eight exact Notion source files from one verified P3 bundle."""
import argparse,json
from pathlib import Path
from import_original_scenes import ROOT,REMOTE_AUDIT,SOURCE,DEST,MANIFEST,fnv1a32,run
SCHEMA="pokerroad_notion_v4_2_verbatim_bundle_1"

def reconstruct(bundle:Path,source:Path=SOURCE,dest:Path=DEST,commit_source_status:bool=False,manifest_path:Path=MANIFEST)->dict:
    data=json.loads(bundle.read_text(encoding="utf-8")); manifest=json.loads(manifest_path.read_text(encoding="utf-8")); remote=json.loads(REMOTE_AUDIT.read_text(encoding="utf-8"))
    if data.get("schema")!=SCHEMA or data.get("game_implementation_status")!="NOT_IMPLEMENTED":
        raise ValueError("wrong source-bundle schema or invalid implementation status")
    regions=data.get("regions",[])
    if not isinstance(regions,list) or len(regions)!=8: raise ValueError("verbatim Notion bundle requires eight original regions")
    remote_by_id={r["id"]:r for r in remote["regions"]}; validated=[]
    for declared,page,meta in zip(manifest["regions"],regions,remote["regions"]):
        region=declared["id"]
        if page.get("id")!=region or page.get("source_page_id","").replace("-","")!=declared["source_page_id"].replace("-",""):
            raise ValueError(f"wrong original source ID/order in region {region}")
        if page.get("source_revision")!="15_v4.2" or page.get("scene_ids")!=declared["scene_ids"]:
            raise ValueError(f"wrong original scene scope/order in region {region}")
        text=page.get("verbatim_enhanced_markdown")
        if not isinstance(text,str): raise ValueError(f"region {region} has no actual original markdown")
        raw=text.encode("utf-8"); expected=remote_by_id[region]
        if len(raw)!=expected["source_utf8_bytes"] or fnv1a32(raw)!=expected["fnv32"]:
            raise ValueError(f"region {region} original markdown fingerprint mismatch")
        validated.append((region,raw))
    source.mkdir(parents=True,exist_ok=True)
    for region,raw in validated: (source/f"15_{region}.md").write_bytes(raw)
    return run(source,dest,manifest_path=manifest_path,verify_remote=True,commit_source_status=commit_source_status)

if __name__=="__main__":
    p=argparse.ArgumentParser(); p.add_argument("--bundle",type=Path,required=True); p.add_argument("--commit-source-status",action="store_true")
    p.add_argument("--source",type=Path,default=SOURCE); p.add_argument("--dest",type=Path,default=DEST)
    a=p.parse_args(); print(json.dumps(reconstruct(a.bundle,a.source,a.dest,a.commit_source_status),ensure_ascii=False,indent=2))
