" curl.vim - A simple wrapper for curl
" Maintainer:   Andreas Müller <http://0x7.ch>
" Version:      0.1

if exists('g:loaded_curl') || &cp
  finish
endif
let g:loaded_curl = 1

" global defaults
if !exists("g:curl_cmd_args")
	let g:curl_cmd_args       = ['--dump-header -']
endif
if !exists("g:curl_filetype")
	let g:curl_filetype       = ''
endif
if !exists("g:curl_http_headers")
	let g:curl_http_headers   = {'Connection': 'close'}
endif
if !exists("g:curl_url_protocol")
	let g:curl_url_protocol   = 'http'
endif
if !exists("g:curl_url_host")
	let g:curl_url_host       = 'localhost'
endif
if !exists("g:curl_url_port")
	let g:curl_url_port       = ''
endif
if !exists("g:curl_url_path")
	let g:curl_url_path       = '/'
endif
if !exists("g:curl_url_parameters")
	let g:curl_url_parameters = {}
endif
if !exists("g:curl_http_headers")
	let g:curl_http_headers   = {}
endif
if !exists("g:curl_remove_cr")
	let g:curl_remove_cr      = 1
endif
if !exists("g:curl_filter")
	let g:curl_filter         = ''
endif

command! -nargs=* CurlGet call CurlGet(<f-args>)
command! -nargs=* CurlHead call CurlHead(<f-args>)
command! -range -nargs=* CurlPost <line1>,<line2>call s:curl('POST', <f-args>)
command! -range -nargs=* CurlPut <line1>,<line2>call s:curl('PUT', <f-args>)
command! -nargs=* CurlDelete <line1>,<line2>call CurlDelete(<f-args>)

function! CurlGet(...)
	call s:curl('GET',a:000)
endfunction

function! CurlHead(...)
	call s:curl(HEAD, a:000)
endfunction

function! CurlPost(...) range
	execute a:firstline.",".a:lastline."call s:curl('POST', a:000)"
endfunction

function! CurlPut(...) range
	execute a:firstline.",".a:lastline."call s:curl('PUT', a:000)"
endfunction

function! CurlDelete(...)
	call s:curl('DELETE', a:000)
endfunction

function! s:curl(method, arguments) range
	" method
	let l:method = toupper(a:method)
	if index(['GET', 'PUT', 'POST', 'HEAD', 'DELETE'], l:method)<0
		echoerr "No such method: ".l:method
		return -1
	endif

	" base command
	if l:method != 'POST' && l:method != 'PUT'
		let l:curl = '0r!curl --silent'
		let l:data = []
	else
		let l:curl = "%!curl --silent"
		let l:data = getline(a:firstline, a:lastline)
	end

	" add method
	let l:curl .= ' --request '.l:method

	" variables - buffer variables take precendence over global variables
	for l:varname in ['cmd_args', 'filetype', 'url_protocol', 'url_host', 'url_port', 'url_path', 'url_parameters',  'http_headers', 'remove_cr', 'filter']
		if exists('b:curl_'.l:varname)
			execute 'let l:'.l:varname.' = b:curl_'.l:varname
		else
			execute 'let l:'.l:varname.' = g:curl_'.l:varname
		endif
	endfor

	" URL path in arguments?
	if len(a:arguments) > 0
		let l:url_path = a:arguments[0]
	end
	if len(l:url_path) == 0 || l:url_path[0] != '/'
		let l:url_path = '/'.l:url_path
	endif

	" URL parameters in arguments?
	if len(a:arguments) > 1
		let l:cmdline_url_parameters = {}
		for item in a:arguments[1:]
			let l:cmdline_url_parameters[split(item, '=')[0]] = split(item, '=')[1]
		endfor
		call extend(l:url_parameters, l:cmdline_url_parameters)
	end

	" post-data
	if l:method ==  "POST" || l:method == "PUT"
		let l:curl .= " --data @-"
	end

	" curl arguments
	let l:curl .= ' '.join(l:cmd_args, ' ')

	" HTTP headers
	if strlen(l:filetype) > 0
		call extend(l:http_headers, {"Accept": "application/".l:filetype, "Content-type": "application/".l:filetype})
	endif
	let l:curl .= join(map(values(map(copy(l:http_headers), 'v:key.": ".v:val')),'" -H \"".v:val."\""'), '')

	" URL
	let l:curl .= ' "'.l:url_protocol.'://'.l:url_host.(l:url_port == '' ? '' : ':').l:url_port.l:url_path
	if len(l:url_parameters) > 0
		let l:curl .= '?'.join(values(map(copy(l:url_parameters), 'v:key."=".v:val')), "&")
	end
	let l:curl .= '"'

	" create temporary buffer
	call s:ScratchBuffer(l:filetype, l:method, l:url_path)
	call setline(1, l:data)
	" call curl
	if len(l:data) > 0
		echo "curl data:"
	echo join(l:data, "\n")
	endif
	echo 'curl command line:'
	echo l:curl
	let g:curl_status = ''
	execute l:curl
	" post-processing
	if v:shell_error == 0
		" remove CR
		if l:remove_cr
			try | :%s/<C-M>//g | catch | endtry
		endif
		" apply filter if given && command returned no error
		if exists("l:filter") && strlen(l:filter) > 0
			try | execute "%!".l:filter | catch | endtry
		endif
	endif
	" go to top
	1
endfunction

function! s:ScratchBuffer(filetype, method, path)
	new
	setlocal buftype=nofile
	setlocal noswapfile
	" setlocal bufhidden=hide
	" setlocal nobuflisted
	execute "file [Scratch:\ ".a:method."\ ".a:path."\ (".localtime().")]"
	if len(a:filetype) > 0
		execute 'setlocal filetype='.a:filetype
	endif
endfunction
