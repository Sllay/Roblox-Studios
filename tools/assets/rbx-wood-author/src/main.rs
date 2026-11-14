use std::{fs::File,io::{BufReader,BufWriter}};
use rbx_dom_weak::{InstanceBuilder,types::{Content,Enum,Color3}};
fn main()->Result<(),Box<dyn std::error::Error>>{
 let a:Vec<String>=std::env::args().collect();
 if a.len()!=4{return Err("usage: rs-rbx-wood-author input output barkUri".into());}
 if !a[3].starts_with("rbxassetid://"){return Err("invalid texture URI".into());}
 let mut dom=rbx_binary::from_reader(BufReader::new(File::open(&a[1])?))?;
 let roots=dom.root().children().to_vec();
 if roots.len()!=1{return Err("one Model root required".into());}
 let mut meshes=Vec::new();
 for i in dom.descendants(){
   if i.class.as_str()=="MeshPart"{
      if !["Wood_V4","Wood_V42","Wood_V43"].contains(&i.name.as_str()){return Err("unexpected wood mesh name".into());}
      meshes.push(i.referent());
   }
   if i.class.as_str().ends_with("Script")||i.class.as_str()=="SurfaceAppearance"{return Err("unexpected script/surface".into());}
 }
 if meshes.len()!=3{return Err("expected three existing wood material groups".into());}
 for r in meshes{
   dom.insert(r,InstanceBuilder::new("SurfaceAppearance")
     .with_name("BarkTint")
     .with_property("ColorMapContent",Content::from_uri(a[3].as_str()))
     .with_property("AlphaMode",Enum::from_u32(2))
     .with_property("Color",Color3::new(0.58,0.34,0.18)));
 }
 rbx_binary::to_writer(BufWriter::new(File::create(&a[2])?),&dom,&roots)?;
 Ok(())
}
