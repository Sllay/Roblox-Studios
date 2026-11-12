use std::{fs::File, io::BufReader};
use rbx_dom_weak::types::Variant;
use serde_json::{json,Map,Value};
fn main() -> Result<(), Box<dyn std::error::Error>> {
    let file=std::env::args().nth(1).ok_or("missing file")?;
    let dom=rbx_binary::from_reader(BufReader::new(File::open(file)?))?;
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
        rows.push(json!({"name":item.name,"properties":props}));
    }
    println!("RBXM_PBR {}",serde_json::to_string(&rows)?);
    Ok(())
}
