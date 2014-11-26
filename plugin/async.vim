"===================================================================
"Debug Tips: 1. if b:syntastic_loclist is set, and statusline flag
" is display properly. check whether server use remote_expr, if yes,
" then check buflist on client throught :ls!. this probably because
" s:FixRawErrors() pick up wrong bufnr. check if filename is escaped
" properly.
"===================================================================

if exists("g:syntastic_enable_async")
    finish
endif

" scripts inside plugin/syntastic need this variable to load
if exists("g:loaded_syntastic_plugin")
    finish
endif
let g:loaded_syntastic_plugin = 1

if !exists("g:syntastic_server_debug")
    let g:syntastic_server_debug = 0
endif

let s:running_windows = (has("win32") || has("win95") || has("win64") || has("win16"))

" using vim as server under windows, don't set encoding to utf-8
" otherwise cjk file name will not work.
if !s:running_windows
  set encoding=utf-8
endif
set cpoptions=aABceFs
" some checker pass relative filename, we need to change work dir path
set autochdir
set noswapfile

" loading syntastic utils scripts and checker scripts
let &rtp = &rtp . ',' . expand("<sfile>:p:h:h")
runtime! plugin/syntastic/*.vim
" objgcc checker has some problem, try use g:SyntasticRegistry. does
" checker really need these to find preprocess func?
" TODO: maybe we can reduce info send to server to begin syntax check.
let s:registry = g:SyntasticRegistry.Instance()

let s:connected_clients = {}

function SyntasticServerDispatchHandler(message)
    if match(a:message, '^syntastic@@@@') != -1
        call s:SyntasticServerAsyncCheck(a:message)
    elseif match(a:message, '^syntastic_aggregate@@@@') != -1
        call s:SyntasticServerAsyncAggregateCheck(a:message)
    endif
    " TODO: none match, maybe tell client about it.

    " avoid 'please press enter or something to continue' message
    call feedkeys("\<CR>")
endfunction

function s:SyntasticServerAsyncCheck(message)
    call s:SyntasticProcessCheckMsg(a:message, 0)
endfunction

function s:SyntasticServerAsyncAggregateCheck(message)
    call s:SyntasticProcessCheckMsg(a:message, 1)
endfunction

function s:SyntasticProcessCheckMsg(message, aggregate_errors)
    let options = s:SandboxEvalOnDictStr(s:SecureCheckOnMapStr(split(a:message, '@@@@')[1]))

    let long_fname = options['long_fname']
    let cwd = options['cwd']
    let checker_filetype_options_list = options['checker_filetype_options_list']
    let client_name = get(options, 'client_name', '')
    let use_remote_expr = !empty(client_name) ? 1 : 0
    let client_address = expand('<client>')
    let global_quiet_messages = get(options, 'global_quiet_messages', {})
    let exit_checks = get(options, 'exit_checks', 0)

    let checker_ft_output_list = []
    let sp_checker_map = {}
    let remain_ft_checkers_map = {}
    let exit_message_list = []
    let warn_msg_list = []
    let error_bufnr_long_fname_map = {}
    if use_remote_expr
        let server_bufnr_client_bufnr_map = {}
    endif

    if use_remote_expr
        let s:connected_clients[client_name] = 1
    endif

    " open file in readonly mode
    " Update: syntastic doesn't use lmake cmd with specify makeprg anymore.
    " syntastic#makeprg#build() take care of all things and can be directly
    " used in system(). this left for debug.
    "exec ":view ".fnameescape(long_fname)


    " original SyntasticMake() also change &shell and &shellredir if
    " s:OSSupportsShellredirHack() is true, but this hack according
    " to commnets is used to stop screen flickers. async mode
    " doesn't have this problem.
    let old_errorformat = &errorformat
    let old_lc_messages = $LC_MESSAGES
    let old_lc_all = $LC_ALL

    if isdirectory(cwd)
        " shellescape doesn't work
        exec 'cd '.fnameescape(cwd)
    else
        let warn_msg = cwd.' is not a valid path, check may fail'
        call add(warn_msg_list, warn_msg)
    endif

    " default error message in english, same as SyntasticMake()
    let $LC_MESSAGES = 'C'
    let $LC_ALL = ''

    " this indicate the next un-run checker index
    let next_checker_idx = 0
    " aggregate mode, run all checkers then stack non empty results
    " non aggregate mode, every ft has only one result then stack them
    " together
    for [checker_name, filetype, checker_options] in checker_filetype_options_list
        let next_checker_idx += 1
        let makeprg = checker_options['makeprg']
        " in non aggregate mode, special checker's result is gurantee to be the
        " end this round of check. no possible to need to run later checkers.
        if has_key(checker_options, 'special_checker')
            " special checker found, its raw_errors is cached raw errors
            call add(checker_ft_output_list, [checker_name, filetype, checker_options['raw_errors']])
            let sp_checker_map[checker_name] = 1
            if a:aggregate_errors
                continue
            else
                break
            endif
        endif

        if has_key(checker_options, 'cwd')
            exec 'cd '.fnameescape(checker_options['cwd'])
        endif

        " set environment variables
        let env_save = {}
        if has_key(checker_options, 'env') && len(checker_options['env'])
            for key in keys(checker_options['env'])
                if key =~? '\m^[a-z_]\+$'
                    exec 'let env_save[' . string(key) . '] = $' . key
                    exec 'let $' . key . ' = ' . string(checker_options['env'][key])
                endif
            endfor
        endif

        let output = system(makeprg)
        let s_shell_error = v:shell_error
        let valid_exit_code = get(checker_options, 'returns', [])

        let err_lines = split(output, "\n", 1)

        " restore environment variables
        if len(env_save)
            for key in keys(env_save)
                exec 'let $' . key . ' = ' . string(env_save[key])
            endfor
        endif

        " move up exit code validation codes according to sync version
        let unaccepted_exit_code = !empty(valid_exit_code) &&
                    \ index(valid_exit_code, s_shell_error) == -1
        if unaccepted_exit_code
            " server2client is a block api, it will block until
            " client read the message. so we choose to pass it
            " with check result.
            call add(exit_message_list, [checker_name, filetype, s_shell_error])
            call setqflist([])
        endif

        let bailout = exit_checks && unaccepted_exit_code

        if bailout
            continue
        endif

        " WARN: hope preprocess don't involve any setting variable, because
        " client don't pass any setting variables.
        "
        " TODO: try and catch, send back error message?
        if has_key(checker_options, 'Preprocess')
            " capital version is (external) preprocess
            let err_lines = call(checker_options['Preprocess'], [err_lines])
        elseif has_key(checker_options, 'preprocess')
            let err_lines = call('syntastic#preprocess#' . checker_options['preprocess'], [err_lines])
        endif

        let &errorformat = checker_options['errorformat']

        cgetexpr err_lines

        if unaccepted_exit_code
            call setqflist([])
        endif

        let raw_errors = getqflist()

        let valid_entry_num = len(filter(copy(raw_errors), 'v:val["valid"] == 1'))

        " must copy, otherwise global_quiet_messages will get polluted
        let quiet_filters = copy(global_quiet_messages)
        " apply g:syntastic_quiet_messages and checker's quiet messages,
        " this is same behaviour as non-async version.
        if has_key(checker_options, 'quiet_messages')
            "let filter = checker_quiet_messages_map[checker_name]
            call extend(quiet_filters, copy(checker_options['quiet_messages']), 'force')
        endif
        if !empty(quiet_filters)
            call syntastic#util#dictFilter(raw_errors, quiet_filters)
        endif

        " NOTE: according to non async version, entries with valid field
        " 0 get cleared when they come to loclist.New() after all post
        " processes. it maybe too early to consider they as real invalid
        " here. But most of checkers don't revert valid field back to 1,
        " so we may filter them out.
        let emptyqf = empty(filter(copy(raw_errors), 'v:val["valid"] == 1'))

        if emptyqf && valid_entry_num > 0
            let message = checker_name.' after applying quiet messages'.
                        \ ' delete all error entries.'
            call add(warn_msg_list, message)
        endif

        if has_key(checker_options, 'cwd')
            " shellescape doesn't work
            exec 'cd '.fnameescape(cwd)
        endif

        if !emptyqf

            if use_remote_expr
                " since cilent provide client_name, we can use remote_expr(), raw_errors
                " can be pass to client instead of system() output string.
                let raw_errors = s:FixRawErrors(raw_errors, client_name, server_bufnr_client_bufnr_map)
            else
                " setup a map for client to fix the wrong bufnr
                for error in raw_errors
                    let bufnr = error['bufnr']
                    let valid = error['valid']
                    if !valid
                        continue
                    endif

                    if !has_key(error_bufnr_long_fname_map, bufnr)
                        let long_fname = fnameescape(expand("#".bufnr.":p"))
                        let error_bufnr_long_fname_map[bufnr] = long_fname
                    endif
                endfor
            endif

            call add(checker_ft_output_list, [checker_name, filetype, raw_errors])

            if !a:aggregate_errors
                " without exec, vim complain next_checker_idx is not defined.
                " also type(next_checker_idx) == type(1), and match() return
                " type(1) too, but match()'s result can be used without exec.
                exec 'let remain_ft_checkers_map = s:GroupByFiletype(checker_filetype_options_list['
                            \ .next_checker_idx.':])'
                break
            endif
        endif
    endfor

    let &errorformat = old_errorformat
    let $LC_ALL = old_lc_all
    let $LC_MESSAGES = old_lc_messages

    let msg_header = a:aggregate_errors ? 'syntastic_aggregate' : 'syntastic'

    let rpc_options = {}
    let rpc_options['long_fname'] = long_fname
    let rpc_options['checker_ft_output_list'] = checker_ft_output_list
    let rpc_options['exit_message_list'] = exit_message_list
    let rpc_options['warn_msg_list'] = warn_msg_list
    let rpc_options['sp_checker_map'] = sp_checker_map
    if !empty(remain_ft_checkers_map)
        let rpc_options['remain_ft_checkers_map'] = remain_ft_checkers_map
    endif
    if use_remote_expr
        let rpc_options['remote_expr'] = 1
    endif
    if !use_remote_expr
        let rpc_options['bufnr_long_fname_map'] = error_bufnr_long_fname_map
    endif

    let message = msg_header.'@@@@'.string(rpc_options)
    call server2client(client_address, message)
endfunction

function s:SecureCheckOnMapStr(str)
    if !empty(a:str) && a:str[0] ==# '{' && a:str[len(a:str)-1] ==# '}'
        return a:str
    endif
    throw a:str." not a Dictionary string"
endfunction

function s:SecureCheckOnListStr(str)
    if !empty(a:str) && a:str[0] ==# '[' && a:str[len(a:str)-1] ==# ']'
        return a:str
    endif
    throw a:str." not a List string"
endfunction

" eval() is danger, put inside a sandbox
function s:SandboxEvalOnDictStr(str)
    let dict = {}
    " dict_str will get wrapped by doublequote, so '\' and '"' must be escaped first
    let dict_str = escape(a:str, '\"')
    sandbox exec "let dict = eval(\"".dict_str."\")"
    return dict
endfunction

" copy from syntastic.vim with small modification
function! s:IgnoreFile(filename, ignore_files_list)
    let fname = fnamemodify(a:filename, ':p')
    for p in a:ignore_files_list
        if fname =~# p
            return 1
        endif
    endfor
    return 0
endfunction

" this func try to fix inconsistent with client bufnr, file bufnr on server is
" different than same file bufnr on client. this func use remote_expr to get
" the client bufnr.
" NOTE: client_name is client's v:servername
function! s:FixRawErrors(raw_errors, client_name, server_bufnr_client_bufnr_map)
    let fixed_raw_errors = copy(a:raw_errors)
    " check and fix every error's bufnr
    for error in fixed_raw_errors
        let wrong_bufnr = error['bufnr']
        let valid = error['valid']
        " non valid entry always get bufnr 0 ? 0 is the alternate
        " buffer for the current window. it's nothing to do with
        " an real error, rarely non-valid entries get change back
        " to valid. so we may safety skip them.
        if !valid
            continue
        endif

        if !has_key(a:server_bufnr_client_bufnr_map, wrong_bufnr)
           " error comprise a file which is not one in the message
           " we need to get the related bufnr in client in order to update
           " can't use fnameescape() here, only \ is need to be escaped, but
           " have to escape two times. because we wrap name with doublequote.
           let full_path_name = escape(expand("#".wrong_bufnr.":p"), '\')
           let full_path_name = escape(full_path_name, '\')
           " TODO: str2nr may have size problem?
           let client_bufnr = str2nr(remote_expr(a:client_name, "bufnr(expand(\"".
                       \ full_path_name."\"), 1)"), 10)
           let a:server_bufnr_client_bufnr_map[wrong_bufnr] = client_bufnr

           let error['bufnr'] = client_bufnr
           continue
        endif

        let error['bufnr'] = a:server_bufnr_client_bufnr_map[wrong_bufnr]
    endfor

    return fixed_raw_errors
endfunction

function! s:GroupByFiletype(checker_filetype_options_list)
    let ft_checker_map = {}
    let cur_filetype = ''
    let cur_checker_list = []
    for [checker_name, filetype, checker_options] in a:checker_filetype_options_list
        if cur_filetype ==# ''
            let cur_filetype = filetype
            let cur_checker_list = [checker_name]
        elseif cur_filetype ==# filetype
            call add(cur_checker_list, checker_name)
        else
            let ft_checker_map[cur_filetype] = cur_checker_list
            let cur_filetype = filetype
            let cur_checker_list = [checker_name]
        endif
    endfor
    " last filetype's checkers get on board
    if !empty(cur_checker_list)
        let ft_checker_map[cur_filetype] = cur_checker_list
    endif

    return ft_checker_map
endfunction

function s:AmIServer()
    let self_name = v:servername
    let server_list_str = string(serverlist())
    let has_server = server_list_str =~? '\<syntastic\>'
    " the first priority servername is SYNTASTIC without number
    if self_name =~? '\<syntastic\>'
        return 1
    elseif has_server && self_name !~? '\<syntastic\>'
        exit
    endif

    let has_server = server_list_str =~? '\<syntastic\d\+\>'
    " serverlist() will sort the servername from small to big, so
    " SYNTASTIC1 come before SYNTASTIC2
    let servername = matchstr(server_list_str, 'SYNTASTIC\d\+')
    if self_name ==# servername
        return 1
    endif
    exit
endfunction

function s:Minimized()
    " gnome-terminal can set WM_WINDOW_ROLE with --role argument.
    exec ":!xwit -iconify -property WM_WINDOW_ROLE -names \"syntastic_server\""
endfunction

fun TryCloseServer(name)
    if !empty(a:name) && has_key(s:connected_clients, a:name)
        unlet s:connected_clients[a:name]
    endif
    if empty(s:connected_clients)
        exec ":qa!"
    endif
    " check if remainding clients are alive
    for vim in keys(s:connected_clients)
        if vim ==# v:servername
            " should never happen
            continue
        endif
        try
            if remote_expr(vim, "g:loaded_syntastic_plugin") == "1"
                return
            endif
        catch /^Vim\%((\a\+)\)\=:E449/	" catch error E123
            break
        endtry
    endfor
    exec ":qa!"
endf

if !exists("g:syntastic_server_loaded")
    let g:syntastic_server_loaded = 1

    " use xwit to iconify vim server
    if has('unix') && executable('xwit')
        augroup server_minimized
            au!
            au VimEnter * call s:Minimized() | exec "au! server_minimized"
        augroup END
    endif

    " check if itself is the one client used, if not, exit.
    if has('unix')
        augroup check_server_number
            au!
            au VimEnter * call s:AmIServer() | exec "au! check_server_number"
        augroup END
    endif
endif

