module publisher

import os

pub fn (page Page) path_get(mut publisher &Publisher) string {
	site_path := publisher.sites[page.site_id].path
	return os.join_path(site_path, page.path)
}

// will load the content, check everything, return true if ok
pub fn (mut page Page) check(mut publisher &Publisher) bool {
	_ := page.markdown_get(mut publisher)
	if page.state == PageStatus.error {
		return false
	}
	return true
}

fn (mut page Page) error_add(error PageError,mut publisher &Publisher) {
	if page.state != PageStatus.error {
		// only add when not in error mode yet, because means check was already done
		page.errors << error
	} else {
		panic(' ** ERROR (2nd time): in file ${page.path_get(mut publisher)}')
	}
}

////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////

// process the markdown content and include other files, find links, ...
// find errors
pub fn (mut page Page) process(mut publisher &Publisher) ? {
	if page.status == PageStatus.ok {
		// means was already processed, content is available
		return
	}

	path_source := page.path_get(mut publisher)
	page.content := os.read_file(path_source) or {
		return error('Failed to open $path_source\nerror:$err')
	}

	page.process_links(mut publisher)	//first find all the links
	page.process_includes(mut publisher) // should be recursive now

	return
}



//walk over each line in the page
fn ( page Page) process_links(linkparseresult &ParseResult, publisher &Publisher) ?string {	

	mut nr := 0
	mut lines_source := ""  //needs to be written to the file where we loaded from, is returned as string
	mut lines_server := ''   //the return of the process, will go back to page.content

	mut sourcelink := "" //what we will replace with on source
	mut serverlink := ""
	mut link_link := ""

	mut sourceline := "" //what we will replace with on source
	mut serverline := ""

	//first we need to do the links, then the process_includes

	mut site := &publisher.sites[page.site_id]
	sitename := site.name

	mut links_parser_result = ParseResult{}

	errors := []""

	for line in page.content.split_into_lines() {
		// println (line)
		nr++
		errors = []""
		
		sourceline = line //what we will replace with on source
		serverline = line		

		links_parser_result = link_parser(line)

		//there can be more than 1 link on 1 line
		for mut link in links_parser_result.links {

			sourcelink = "" //the result for how it should be in the source file
			serverlink = "" //result of how it needs to be on the server

			link_description := link.name.trim(" ")

			//only when local we need to check if we can find files/pages or not
			if !link.isexternal && link.cat != LinkType.unknown{

				//parse the different variations of how we can mention a link
				// supported:
				//  site:name
				//  page__sitename__itemname
				//  file__sitename__itemname
				sitename2,itemname := site_page_names_get(link.link)
				if sitename2 != "" {
					//means was specified in the link
					//if not returned means its the site name from the site we are on
					sitename = sitename2
				}

				//we only need the last name for local content
				//can be for file, file & page
				itemname = os.file_name(itemname)

				if link.cat == LinkType.page{
					if publisher.page_exists(link.link)) {
						serverlink = 'page__${sitename}__${itemname}'
					}else{
						errormsg =  "ERROR: CANNOT FIND LINK: '${link.link}' for $link_description"
						errors << errormsg
						page.error_add({
							line:   line
							linenr: linenr
							msg: errormsg  
							cat:    PageErrorCat.brokenlink
						})
						serverlink = "> $errormsg"
					}
				} else {
					if publisher.file_exists(link.link)) {
						serverlink = 'file__${sitename}__${itemname}'

						//remember that the file has been used
						_, mut img := publisher.file_get(link.link) or {panic("bug")}
						if !(page.name in img.usedby){
							img.usedby<<page.name
						}

					}else{
						errormsg =  "ERROR: CANNOT FIND FILE: '${link.link}' for $link_description"
						errors << errormsg
						page.error_add({
							line:   line
							linenr: linenr
							msg:    errormsg
							cat:    PageErrorCat.brokenlink
						})
						serverlink = "> $errormsg"
					}					
				}

				//now we need to cleanup the source
				if site.name == sitename{
					link_link = itemname
				} else{
					link_link = "$sitename:$itemname"
				}
				
			}else{
				//was no page or file on the localserver
				//we can only do some generic cleanup now
				link_link = link.link.trim(" ")
			}

			//lets cleanup the sourcecode & the code which will come from server

			sourcelink = "[${link_description}](${link_link})"
			
			if serverlink == ""{
				serverlink = sourcelink
			}

			if link.isimage{
				sourcelink = "!${sourcelink}"
				serverlink = "!${serverlink}"
			}			

			sourceline=sourceline.replace(link.link_original_get(),sourcelink)
			serverline=serverline.replace(link.link_original_get(),serverlink)

		}//end of the walk over all links

		lines_source += sourceline + "\n"
		lines_server += serverline + "\n"

		//now we need to check if there were errors if yes lets put them in the source code
		//this will make it easy to spot errors and fix, remember endusers will see it too
		for err in errors{
			lines_source += "> **ERROR: $err<br>\n"
			lines_server += "> **ERROR: $err<br>\n"
		}

	}//end of the line walk

	page.content = line_server //we need to remember what the server needs to give
	//we return the source lines, so we can choose to store it on fs or not
	return lines_source

}



fn (mut page Page) process_includes(mut publisher &Publisher) string {
	
	mut lines := ''   //the return of the process
	mut nr := 0

	// site := &publisher.sites[page.site_id]
	for line in page.content.split_into_lines() {
		// println (line)
		nr++

		mut linestrip := line.trim(' ')
		if linestrip.starts_with('!!!include') {
			name := linestrip['!!!include'.len + 1..]
			// println('-includes-- $name')
			mut _, mut page_linked := publisher.page_get(name) or {
				// println("-includes-- could not get page $name")
				page_error := PageError{
					line: line
					linenr: nr
					msg: "Cannot inlude '$name'\n$err"
					cat: PageErrorCat.brokeninclude
				}
				page.error_add(page_error, mut publisher)
				lines += '> ERROR: $page_error.msg'
				continue
			}
			if page_linked.path_get(mut publisher) == page.path_get(mut publisher) {
				panic('recursive include: ${page_linked.path_get(mut publisher)}')
			}
			page_linked.nrtimes_inluded++
			// path11 := page_linked
			content_linked := page_linked.markdown_get(mut publisher)
			lines += content_linked + '\n'
		} else {
			lines += line + '\n'
		}
	}
	return lines
}

