module publishingtools
import os

struct ImageActor {
	pub mut:
		site Site
		publtools PublTools		
		image Image
}

//return fullpath,imageobject
pub fn (site Site) imageactor_get(name string, publtools PublTools) ?ImageActor{	
	namelower := name_fix(name)
	if namelower in site.images {
		mut image2 := site.images[namelower]
		return ImageActor{image:&image2, publtools:&publtools, site:&site}
	}
	return error("Could not find image $namelower in site ${site.name}")
}


pub fn (imageactor ImageActor) path_get() string{
	return os.join_path(imageactor.site.path, imageactor.image.path)
}

pub fn (mut imageactor ImageActor) process(){

}