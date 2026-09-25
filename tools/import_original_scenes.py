#!/usr/bin/env python3
"""Preserve 15 v4.2 sections exactly; never replace with a summary/AI rewrite."""
import argparse, hashlib, json, os, re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
MANIFEST=ROOT/"game/data/world_manifest.json"
SOURCE=ROOT/"source/original_notion_v4_2"
DEST=ROOT/"game/data/original_scenes"
HEADING=re.compile(r"^#{1,4}[ \t]+(?P<id>\d{2}-(?:M|S|T|R)\d{2})\b[^\r\n]*$",re.M)
TOP_LEVEL=re.compile(r"^#[ \t]+[^\r\n]*$",re.M)
REMOTE_AUDIT=ROOT/"docs/NOTION_SOURCE_REMOTE_AUDIT.json"

def fnv1a32(raw:bytes)->str:
    h=2166136261
    for byte in raw: h=((h^byte)*16777619)&0xffffffff
    return f"{h:08x}"

def audit_verbatim_source(region:str,raw:bytes,audit_by_region:dict)->None:
    expected=audit_by_region.get(region)
    if not expected: raise ValueError(f"region {region}: no directly fetched source audit record")
    if len(raw)!=expected["source_utf8_bytes"] or fnv1a32(raw)!=expected["fnv32"]:
        raise ValueError(f"region {region}: source bytes differ from original Notion v4.2; stop import")

def sha256_utf8(s:str)->str: return hashlib.sha256(s.encode("utf-8")).hexdigest()

def extract_sections(text:str,expected:list[str],region:str)->dict[str,str]:
    # Fixtures and local Windows editors may use CRLF. Canonical source byte
    # fingerprints are checked before this parse-only normalization.
    text=text.replace("\r\n","\n")
    matches=list(HEADING.finditer(text))
    if not matches: raise ValueError(f"region {region}: no actual markdown scene headings")
    result={}; order=[]; top_levels=[m.start() for m in TOP_LEVEL.finditer(text)]
    for i,match in enumerate(matches):
        scene_id=match.group("id")
        if not scene_id.startswith(region+"-"): raise ValueError(f"region {region}: foreign scene heading {scene_id}")
        if scene_id not in expected: raise ValueError(f"region {region}: unknown scene {scene_id}")
        end=matches[i+1].start() if i+1<len(matches) else len(text)
        for heading_start in top_levels:
            if match.end()<=heading_start<end: end=heading_start; break
        full_section=text[match.start():end]
        if scene_id!=(order[-1] if order else None):
            if scene_id in result: raise ValueError(f"region {region}: scene reappears after another ID: {scene_id}")
            order.append(scene_id); result[scene_id]=full_section
        else: result[scene_id]+=full_section
    if order!=expected: raise ValueError(f"region {region}: wrong order/missing IDs: got {order}, expected {expected}")
    for scene_id,raw in result.items():
        if len(raw.strip())<80: raise ValueError(f"region {region}: suspiciously short original {scene_id}")
    return result

def run(source:Path,dest:Path,manifest_path:Path=MANIFEST,verify_remote:bool=True,commit_source_status:bool=False)->dict:
    if commit_source_status and not verify_remote: raise ValueError("cannot mark synthetic or unverified source as imported")
    manifest=json.loads(manifest_path.read_text(encoding="utf-8"))
    if len(manifest["regions"])!=8 or len(manifest["scenes"])!=88: raise ValueError("original manifest must contain all 8 regions and 88 scenes")
    remote={}
    if verify_remote:
        remote_data=json.loads(REMOTE_AUDIT.read_text(encoding="utf-8")); remote={r["id"]:r for r in remote_data["regions"]}
    staged=[]; source_page_copies=[]
    audit={"source_revision":"15_v4.2","full_original_source_available":verify_remote,
           "verified_against_remote_notion_audit":verify_remote,"source_flag_advanced_in_manifest":False,
           "scene_source_captured":0,"scene_game_implemented":0,"regions":[]}
    seen=set()
    for region in manifest["regions"]:
        region_id=region["id"]; path=source/f"15_{region_id}.md"
        if not path.is_file(): raise FileNotFoundError(f"Required verbatim Notion source missing: {path}")
        raw_bytes=path.read_bytes()
        if verify_remote: audit_verbatim_source(region_id,raw_bytes,remote)
        text=raw_bytes.decode("utf-8")
        if text.startswith("\ufeff"): raise ValueError(f"region {region_id}: unexpected BOM in exact Notion source")
        source_page_copies.append((dest.parent/"source_pages_verbatim"/f"15_{region_id}.md",raw_bytes))
        expected=region["scene_ids"]; extracts=extract_sections(text,expected,region_id)
        region_result={"id":region_id,"source_page_id":region["source_page_id"],"source_file_sha256":hashlib.sha256(raw_bytes).hexdigest(),"scene_count":len(extracts),"scenes":[]}
        for scene_id,section in extracts.items():
            if scene_id in seen: raise ValueError(f"duplicate scene ID across regions: {scene_id}")
            seen.add(scene_id)
            data={"scene_id":scene_id,"source_page_id":region["source_page_id"],"source_revision":"15_v4.2",
                  "verbatim_source_markdown":section,"source_section_sha256":sha256_utf8(section),
                  "source_import_status":"ORIGINAL_TEXT_CAPTURED","game_implementation_status":"NOT_IMPLEMENTED",
                  "game_qa_status":"QA_NOT_RUN","note":"Captured original scene prose and all same-ID supplementary sections; not parsed into runnable dialogue/actions."}
            staged.append((dest/f"{scene_id}.json",(json.dumps(data,ensure_ascii=False,indent=2)+"\n").encode("utf-8")))
            region_result["scenes"].append({"id":scene_id,"sha256":data["source_section_sha256"]})
        audit["scene_source_captured"]+=len(extracts); audit["regions"].append(region_result)
    if len(seen)!=88: raise ValueError("incomplete original scene import")
    dest.mkdir(parents=True,exist_ok=True); source_page_copies[0][0].parent.mkdir(parents=True,exist_ok=True)
    for path,payload in source_page_copies: path.write_bytes(payload)
    for path,payload in staged: path.write_bytes(payload)
    if commit_source_status:
        for scene in manifest["scenes"]:
            if scene["id"] not in seen or scene.get("game_implementation_status")!="NOT_IMPLEMENTED":
                raise ValueError("cannot certify inconsistent source or already implemented scene")
            scene["source_import_status"]="IMPORTED"
        manifest_bytes=(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n").encode("utf-8")
        temporary=manifest_path.with_suffix(".json.source-import-tmp"); temporary.write_bytes(manifest_bytes); os.replace(temporary,manifest_path)
        audit["source_flag_advanced_in_manifest"]=True
    (dest.parent/"source_import_audit.json").write_text(json.dumps(audit,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    return audit

if __name__=="__main__":
    p=argparse.ArgumentParser(); p.add_argument("--source",type=Path,default=SOURCE); p.add_argument("--dest",type=Path,default=DEST)
    p.add_argument("--commit-source-status",action="store_true"); p.add_argument("--synthetic-fixture-only",action="store_true")
    a=p.parse_args(); result=run(a.source,a.dest,verify_remote=not a.synthetic_fixture_only,commit_source_status=a.commit_source_status)
    if a.synthetic_fixture_only:
        result["full_original_source_available"]=False; result["source_revision"]="SYNTHETIC_TEST_ONLY_NOT_REAL_NOTION"
        (a.dest.parent/"source_import_audit.json").write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(result,ensure_ascii=False,indent=2))
