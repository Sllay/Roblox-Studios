use std::{fs::File,io::{BufReader,BufWriter}};
use rbx_dom_weak::{InstanceBuilder,types::{Content,Enum,Color3}};
fn main()->Result<(),Box<dyn std::error::Error>>{
 let a:Vec<String>=std::env::args().collect();
 if a.len()!=5{return Err("usage: rbx-author input output whiteUri grayUri".into());}
 let mut dom=rbx_binary::from_reader(BufReader::new(File::open(&a[1])?))?;
 let roots=dom.root().children().to_vec();
 if roots.len()!=1{return Err("one Model root required".into());}
 let mut meshes=0;
 let mut canopy=Vec::new();
 for i in dom.descendants(){
   if i.class.as_str()=="MeshPart"{
      meshes+=1;
      if i.name=="Canopy_White"||i.name=="Canopy_Gray"{
         if !i.children().is_empty(){return Err("unexpected canopy children".into());}
         canopy.push((i.referent(),i.name.clone()));
      }
   }
   if i.class.as_str().ends_with("Script"){return Err("script not allowed".into());}
 }
 if meshes!=5||canopy.len()!=2{return Err("unexpected geometry".into());}
 for (r,n) in canopy{
   let uri=if n=="Canopy_White"{&a[3]}else{&a[4]};
   if !uri.starts_with("rbxassetid://"){return Err("invalid URI".into());}
   dom.insert(r,InstanceBuilder::new("SurfaceAppearance")
     .with_name(if n=="Canopy_White"{"LeavesWhite"}else{"LeavesGray"})
     .with_property("ColorMapContent",Content::from_uri(uri.as_str()))
     .with_property("AlphaMode",Enum::from_u32(1))
     .with_property("Color",Color3::new(1.0,1.0,1.0)));
 }
 rbx_binary::to_writer(BufWriter::new(File::create(&a[2])?),&dom,&roots)?;
 Ok(())
}
