use std::{fs::File, io::BufReader};
use rbx_dom_weak::types::Variant;
use serde_json::{json,Map,Value};
fn main() -> Result<(), Box<dyn std::error::Error>> {
    let file=std::env::args().nth(1).ok_or("missing file")?;
    let dom=rbx_binary::from_reader(BufReader::new(File::open(file)?))?;
    // SerializeInstancesAsync({model}) has a single authored root under
    // the RBXM document root. Ignore that model name; use exact descendant
    // hierarchy so identically named surfaces on different meshes are distinct.
    let roots=dom.root().children();
    if roots.len()!=1 {return Err("expected one serialized model root".into());}
    let model_ref=roots[0];
    let mut rows=Vec::new();
    for item in dom.descendants() {
        if item.class.as_str()!="SurfaceAppearance" {continue;}
        let mut props=Map::new();
        for (key,val) in &item.properties {
            let name=key.as_str();
            if name.contains("Map") || name.contains("TexturePack") || name.contains("EmissiveMask") {
                props.insert(name.to_string(),match val {
                    Variant::Content(v)=>json!(v),
                    Variant::ContentId(v)=>json!(v.as_str()),
                    Variant::String(v)=>json!(v),
                    _=>json!(format!("{:?}",val)),
                });
            }
        }
        let mut path=Vec::new();
        let mut cursor=item;
        while cursor.referent()!=model_ref {
            let parent=dom.get_by_ref(cursor.parent()).ok_or("surface outside model")?;
            let index=parent.children().iter().position(|r|*r==cursor.referent()).ok_or("missing child")?+1;
            path.push(json!({"name":cursor.name,"class":cursor.class.as_str(),"index":index}));
            cursor=parent;
        }
        path.reverse();
        rows.push(json!({"name":item.name,"path":path,"properties":props}));
    }
    println!("RBXM_PBR {}",serde_json::to_string(&rows)?);
    Ok(())
}
