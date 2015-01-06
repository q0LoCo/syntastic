"============================================================================
"File:        syntastic.vim
"Description: Vim plugin for on the fly syntax checking.
"License:     This program is free software. It comes without any warranty,
"             to the extent permitted by applicable law. You can redistribute
"             it and/or modify it under the terms of the Do What The Fuck You
"             Want To Public License, Version 2, as published by Sam Hocevar.
"             See http://sam.zoy.org/wtfpl/COPYING for more details.
"
"============================================================================

if exists("g:loaded_syntastic_plugin")
    finish
endif
let g:loaded_syntastic_plugin = 1

if has('reltime')
    let g:_SYNTASTIC_START = reltime()
    lockvar! g:_SYNTASTIC_START
endif

let g:_SYNTASTIC_VERSION = '3.5.0-72'
lockvar g:_SYNTASTIC_VERSION

" Sanity checks {{{1

for s:feature in [
            \ 'autocmd',
            \ 'eval',
            \ 'file_in_path',
            \ 'modify_fname',
            \ 'quickfix',
            \ 'reltime',
            \ 'user_commands'
        \ ]
    if !has(s:feature)
        call syntastic#log#error("need Vim compiled with feature " . s:feature)
        finish
    endif
endfor

let s:_running_windows = syntastic#util#isRunningWindows()
lockvar s:_running_windows

if !s:_running_windows && executable('uname')
    try
        let s:_uname = system('uname')
    catch /\m^Vim\%((\a\+)\)\=:E484/
        call syntastic#log#error("your shell " . &shell . " can't handle traditional UNIX syntax for redirections")
        finish
    endtry
    lockvar s:_uname
endif

" }}}1

" Defaults {{{1

let g:_SYNTASTIC_DEFAULTS = {
        \ 'aggregate_errors':         0,
        \ 'always_populate_loc_list': 0,
        \ 'auto_jump':                0,
        \ 'auto_loc_list':            2,
        \ 'bash_hack':                0,
        \ 'check_on_open':            0,
        \ 'check_on_wq':              1,
        \ 'cursor_columns':           1,
        \ 'debug':                    0,
        \ 'echo_current_error':       1,
        \ 'enable_balloons':          1,
        \ 'enable_highlighting':      1,
        \ 'enable_signs':             1,
        \ 'error_symbol':             '>>',
        \ 'exit_checks':              !(s:_running_windows && &shell =~? '\m\<cmd\.exe$'),
        \ 'filetype_map':             {},
        \ 'full_redraws':             !(has('gui_running') || has('gui_macvim')),
        \ 'id_checkers':              1,
        \ 'ignore_extensions':        '\c\v^([gx]?z|lzma|bz2)$',
        \ 'ignore_files':             [],
        \ 'loc_list_height':          10,
        \ 'quiet_messages':           {},
        \ 'reuse_loc_lists':          0,
        \ 'sort_aggregated_errors':   1,
        \ 'stl_format':               '[Syntax: line:%F (%t)]',
        \ 'style_error_symbol':       'S>',
        \ 'style_warning_symbol':     'S>',
        \ 'warning_symbol':           '>>'
    \ }
lockvar! g:_SYNTASTIC_DEFAULTS

for s:key in keys(g:_SYNTASTIC_DEFAULTS)
    if !exists('g:syntastic_' . s:key)
        let g:syntastic_{s:key} = copy(g:_SYNTASTIC_DEFAULTS[s:key])
    endif
endfor

if exists("g:syntastic_quiet_warnings")
    call syntastic#log#oneTimeWarn("variable g:syntastic_quiet_warnings is deprecated, please use let g:syntastic_quiet_messages = {'level': 'warnings'} instead")
    if g:syntastic_quiet_warnings
        let s:quiet_warnings = get(g:syntastic_quiet_messages, 'type', [])
        if type(s:quiet_warnings) != type([])
            let s:quiet_warnings = [s:quiet_warnings]
        endif
        call add(s:quiet_warnings, 'warnings')
        let g:syntastic_quiet_messages['type'] = s:quiet_warnings
    endif
endif

" }}}1

" Debug {{{1

let s:_DEBUG_DUMP_OPTIONS = [
        \ 'shell',
        \ 'shellcmdflag',
        \ 'shellpipe',
        \ 'shellquote',
        \ 'shellredir',
        \ 'shellslash',
        \ 'shelltemp',
        \ 'shellxquote'
    \ ]
if v:version > 703 || (v:version == 703 && has('patch446'))
    call add(s:_DEBUG_DUMP_OPTIONS, 'shellxescape')
endif
lockvar! s:_DEBUG_DUMP_OPTIONS

" debug constants
let     g:_SYNTASTIC_DEBUG_TRACE         = 1
lockvar g:_SYNTASTIC_DEBUG_TRACE
let     g:_SYNTASTIC_DEBUG_LOCLIST       = 2
lockvar g:_SYNTASTIC_DEBUG_LOCLIST
let     g:_SYNTASTIC_DEBUG_NOTIFICATIONS = 4
lockvar g:_SYNTASTIC_DEBUG_NOTIFICATIONS
let     g:_SYNTASTIC_DEBUG_AUTOCOMMANDS  = 8
lockvar g:_SYNTASTIC_DEBUG_AUTOCOMMANDS
let     g:_SYNTASTIC_DEBUG_VARIABLES     = 16
lockvar g:_SYNTASTIC_DEBUG_VARIABLES
let     g:_SYNTASTIC_DEBUG_CHECKERS      = 32
lockvar g:_SYNTASTIC_DEBUG_CHECKERS

" }}}1

runtime! plugin/syntastic/*.vim

let s:registry = g:SyntasticRegistry.Instance()
let s:notifiers = g:SyntasticNotifiers.Instance()
let s:modemap = g:SyntasticModeMap.Instance()

" Commands {{{1

" @vimlint(EVL103, 1, a:cursorPos)
" @vimlint(EVL103, 1, a:cmdLine)
" @vimlint(EVL103, 1, a:argLead)
function! s:CompleteCheckerName(argLead, cmdLine, cursorPos) " {{{2
    let checker_names = []
    for ft in s:_resolve_filetypes([])
        call extend(checker_names, s:registry.getNamesOfAvailableCheckers(ft))
    endfor
    return join(checker_names, "\n")
endfunction " }}}2
" @vimlint(EVL103, 0, a:cursorPos)
" @vimlint(EVL103, 0, a:cmdLine)
" @vimlint(EVL103, 0, a:argLead)


" @vimlint(EVL103, 1, a:cursorPos)
" @vimlint(EVL103, 1, a:cmdLine)
" @vimlint(EVL103, 1, a:argLead)
function! s:CompleteFiletypes(argLead, cmdLine, cursorPos) " {{{2
    return join(s:registry.getKnownFiletypes(), "\n")
endfunction " }}}2
" @vimlint(EVL103, 0, a:cursorPos)
" @vimlint(EVL103, 0, a:cmdLine)
" @vimlint(EVL103, 0, a:argLead)

command! -nargs=* -complete=custom,s:CompleteCheckerName SyntasticCheck call SyntasticCheck(<f-args>)
command! -nargs=? -complete=custom,s:CompleteFiletypes   SyntasticInfo  call SyntasticInfo(<f-args>)
command! Errors              call SyntasticErrors()
command! SyntasticReset      call SyntasticReset()
command! SyntasticToggleMode call SyntasticToggleMode()
command! SyntasticSetLoclist call SyntasticSetLoclist()

" }}}1

" Public API {{{1

function! SyntasticCheck(...) " {{{2
    call s:UpdateErrors(0, a:000)
    call syntastic#util#redraw(g:syntastic_full_redraws)
endfunction " }}}2

function! SyntasticInfo(...) " {{{2
    call s:modemap.modeInfo(a:000)
    call s:registry.echoInfoFor(s:_resolve_filetypes(a:000))
    call s:_explain_skip(a:000)
endfunction " }}}2

function! SyntasticErrors() " {{{2
    call g:SyntasticLoclist.current().show()
endfunction " }}}2

function! SyntasticReset() " {{{2
    call s:ClearCache()
    call s:notifiers.refresh(g:SyntasticLoclist.New([]))
endfunction " }}}2

function! SyntasticToggleMode() " {{{2
    call s:modemap.toggleMode()
    call s:ClearCache()
    call s:notifiers.refresh(g:SyntasticLoclist.New([]))
    call s:modemap.echoMode()
endfunction " }}}2

function! SyntasticSetLoclist() " {{{2
    call g:SyntasticLoclist.current().setloclist()
endfunction " }}}2

" }}}1

" Autocommands {{{1

augroup syntastic
    autocmd BufReadPost  * call s:BufReadPostHook()
    autocmd BufWritePost * call s:BufWritePostHook()
    autocmd BufEnter     * call s:BufEnterHook()
augroup END

if v:version > 703 || (v:version == 703 && has('patch544'))
    " QuitPre was added in Vim 7.3.544
    augroup syntastic
        autocmd QuitPre * call s:QuitPreHook()
    augroup END
endif

function! s:BufReadPostHook() " {{{2
    if g:syntastic_check_on_open
        call syntastic#log#debug(g:_SYNTASTIC_DEBUG_AUTOCOMMANDS,
            \ 'autocmd: BufReadPost, buffer ' . bufnr("") . ' = ' . string(bufname(str2nr(bufnr("")))))
        call s:UpdateErrors(1, [])
    endif
endfunction " }}}2

function! s:BufWritePostHook() " {{{2
    call syntastic#log#debug(g:_SYNTASTIC_DEBUG_AUTOCOMMANDS,
        \ 'autocmd: BufWritePost, buffer ' . bufnr("") . ' = ' . string(bufname(str2nr(bufnr("")))))
    call s:UpdateErrors(1, [])
endfunction " }}}2

function! s:BufEnterHook() " {{{2
    call syntastic#log#debug(g:_SYNTASTIC_DEBUG_AUTOCOMMANDS,
        \ 'autocmd: BufEnter, buffer ' . bufnr("") . ' = ' . string(bufname(str2nr(bufnr("")))) .
        \ ', &buftype = ' . string(&buftype))
    if &buftype == ''
        call s:notifiers.refresh(g:SyntasticLoclist.current())
    elseif &buftype == 'quickfix'
        " TODO: this is needed because in recent versions of Vim lclose
        " can no longer be called from BufWinLeave
        " TODO: at this point there is no b:syntastic_loclist
        let loclist = filter(copy(getloclist(0)), 'v:val["valid"] == 1')
        let owner = str2nr(getbufvar(bufnr(""), 'syntastic_owner_buffer'))
        let buffers = syntastic#util#unique(map(loclist, 'v:val["bufnr"]') + (owner ? [owner] : []))
        if get(w:, 'syntastic_loclist_set', 0) && !empty(loclist) && empty(filter( buffers, 'syntastic#util#bufIsActive(v:val)' ))
            call SyntasticLoclistHide()
        endif
    endif
endfunction " }}}2

function! s:QuitPreHook() " {{{2
    call syntastic#log#debug(g:_SYNTASTIC_DEBUG_AUTOCOMMANDS,
        \ 'autocmd: QuitPre, buffer ' . bufnr("") . ' = ' . string(bufname(str2nr(bufnr("")))))
    let b:syntastic_skip_checks = get(b:, 'syntastic_skip_checks', 0) || !syntastic#util#var('check_on_wq')
    if get(w:, 'syntastic_loclist_set', 0)
        call SyntasticLoclistHide()
    endif
endfunction " }}}2

" }}}1

" Main {{{1


" ----------------------------
"  below is client code {{{1
if !exists("g:syntastic_enable_async")
    let g:syntastic_enable_async = 0
endif

if !exists("g:syntastic_async_delay_error_refresh")
    let g:syntastic_async_delay_error_refresh = 0
endif

if !exists("g:syntastic_async_delay_refresh_time")
    let g:syntastic_async_delay_refresh_time = 2000
endif

if !exists("g:syntastic_async_servername")
    let g:syntastic_async_servername = "SYNTASTIC"
    "NOTE: this variable is used in s:StartupServer, if vim cannot register
    " itself with this name, vim will append 1, 2, 3 etc to the end of name.
    " it's different than servername, async_servername can be SYNTASTIC1 but
    " this one can't, otherwise you will see SYNTASTIC111111 if vim server
    " startup failed multi times.
    let g:syntastic_async_startup_servername = g:syntastic_async_servername
endif

" a round of time you can wait for server startup complete, default is 30, means 3000ms.
if !exists("g:syntastic_async_wait_server_startup_time")
    let g:syntastic_async_wait_server_startup_time = 30
endif

if !exists("g:syntastic_async_tmux_if_possible")
    let g:syntastic_async_tmux_if_possible = 1
endif

if !exists("g:syntastic_async_tmux_new_window")
    let g:syntastic_async_tmux_new_window = 1
endif

function! s:HasServer()
    let server_list = split(serverlist(), "\n")
    return count(server_list, g:syntastic_async_servername)
endfunction

function! s:TellServerExit()
    if s:HasServer()
        let name = '"'.escape(v:servername, '"\').'"'
        call remote_send(g:syntastic_async_servername, "<ESC>:call TryCloseServer(".name.")<CR>")
        "call remote_send(g:syntastic_async_servername, "<ESC>:qa!<CR>")
    endif
endfunction

let s:is_client_ready = 0
function! s:SetupClient()
    " if bufname match and directly update errors interface,
    " cursor will move to other places. So update using CursorHold
    " and CursorHoldI solve the problem.
    if g:syntastic_async_delay_error_refresh
        "set updatetime=2000
        let &updatetime = g:syntastic_async_delay_refresh_time
    endif

    augroup syntastic_async_client
        autocmd!
        autocmd RemoteReply * call s:RemoteReplyMsgDispatcher(remote_read(expand("<amatch>")))
        autocmd VimLeavePre * call s:TellServerExit()
        autocmd BufEnter * call s:NotifyErrors()
        autocmd BufDelete * call s:UpdateBufErrorsNumMap(expand("<afile>"), 0)
        if g:syntastic_async_delay_error_refresh
            autocmd CursorHold,CursorHoldI * call s:NotifyErrors()
        endif
    augroup END

    let s:is_client_ready = 1
endfunction

" start the vim syntastic server if it's not started
let s:syntastic_server_rc='"'.expand("<sfile>:p:h").'/async.vim"'
function! s:StartupServerOnly()
    if !has('clientserver')
        let g:syntastic_enable_async = 0
        return
    endif

    if !s:HasServer()
        let server_rc = s:syntastic_server_rc
        call syntastic#log#debug(g:_SYNTASTIC_DEBUG_TRACE, "StartupServer: server rc: " . server_rc)

        let server = ""
        if executable("vim")
            let server = "vim"
        elseif executable("gvim")
            let server = "gvim"
        else
            let g:syntastic_enable_async = 0
            echom "strange: gvim and vim don't exist on path"
            return
        endif

        let server_cmd = server." -M -u ".server_rc." --noplugin "
                    \ ."--servername ".g:syntastic_async_startup_servername
        " :! use '(cmd &)' and system() use 'cmd &'. system() has redirect
        " pipe by default but :! can do redirect manually. :! without redirection
        " may flicker vim terminal when there are something output.
        if has('unix')
            if server ==# "vim"
                if !empty($TMUX) && !exists('$SUDO_UID') && executable('tmux')
                            \ && g:syntastic_async_tmux_if_possible
                    let cmd = 'tmux split-window -l 6 -d'
                    if g:syntastic_async_tmux_new_window
                        " default window number is 9
                        let cmd = 'tmux new-window -d -n "syntastic_daemon" -t 9'
                    endif
                    let cmd .= ' "'.escape(server_cmd, '"').'"'
                else
                    " gnome-terminal can set WM_WINDOW_ROLE, so xwit can minimize.
                    let cmd = "gnome-terminal --class \"VIMSERVER\" --disable-factory"
                                \ .' --role "syntastic_server"'
                                \ .' -e "'.escape(server_cmd, '"').'" &'
                endif
            else
                " gvim can set WM_WINDOW_ROLE, xwit can minimized it with
                " xwit -iconify -property WM_WINDOW_ROLE -names "syntastic_server"
                let cmd = server_cmd.' --role "syntastic_server" &'
            endif
        else
            let cmd = "start /B ".server_cmd." && exit"
        endif
        call syntastic#log#debug(g:_SYNTASTIC_DEBUG_TRACE, "StartupServer: start server cmd: " . cmd)

        if !has('gui_running')
            " silent :! will cause some display problem, maybe a blank terminal
            " etc. ctrl+l or redraw! fix this problem.
            augroup fix_vim_silent_exe_redraw
                au!
                autocmd CursorMoved,CursorMovedI *  call syntastic#util#redraw(g:syntastic_full_redraws) |
                            \ exec "au! fix_vim_silent_exe_redraw" |
                            \ aug! fix_vim_silent_exe_redraw
            augroup END
        endif
        "call system("start /B gvim -u ".server_rc.cmd." --servername syntastic && exit")
        "silent exec ":!".cmd | call s:Redraw()
        if s:_running_windows
            silent exec ":!".cmd
        else
            call system(cmd)
        endif
    endif
endfunction

fun! s:WaitAFewForServerStart()
    if !s:HasServer()
        let loopcount = g:syntastic_async_wait_server_startup_time
        let halfcount = loopcount / 2
        let warned = 0
        " server register get a delay on unix, we can't start following
        " checker right now, otherwise multi vim or gvim server will
        " startup, client will confuse.
        " TODO: currently we use while and sleep wait for the server
        " startup complete. maybe there is a better way to do this.
        while !s:HasServer() && loopcount >= 0
            let server_str = string(serverlist())
            if server_str =~? 'syntastic\d\+'
                if !warned
                    let t_warning = "multi server instances found, VimRegistry property ".
                                \ "already set on the root window on X-server."
                    call syntastic#log#warn(t_warning)
                    let warned = 1
                endif
                if (halfcount < 10 && loopcount == 0) || (loopcount == halfcount && halfcount > 10)
                    let g:syntastic_async_servername = matchstr(server_str,
                                \ 'SYNTASTIC\d\+')
                    let t_warning_2 = "server cannot set the name to SYNTASTIC, "
                                \ ."previous instance doesn't quit correctly. you need "
                                \ ."to logout to fix this."
                    let t_warning_3 = "change servername to ".g:syntastic_async_servername
                    call syntastic#log#warn(t_warning_2)
                    call syntastic#log#warn(t_warning_3)
                    break
                endif
            endif
            if loopcount == halfcount
                call syntastic#log#warn('server startup slow, wait a bit longer')
            endif
            let loopcount -= 1
            sleep 100m
        endwhile
    endif
endf

let s:total_startup_server_failures = 0
function! s:RemoteSyntasticCheck(msg_header, rpc_options)
    let message = a:msg_header.'@@@@'.string(a:rpc_options)
    " we use doublequote to warp the message, so backslash
    " should be escaped first.
    let message = escape(message, '"\')
    let message = '"'.message.'"'

    if !s:is_client_ready
        call s:SetupClient()
    endif

    if !s:HasServer()
        call s:StartupServerOnly()
        call s:WaitAFewForServerStart()
        if !s:HasServer()
            let s:total_startup_server_failures += 1
            let msg_error = "server fail to startup in time, abandon check this time,".
                        \ " try again later"
            call syntastic#log#error(msg_error)

            if s:total_startup_server_failures == 5
                let g:syntastic_enable_async = 0
                call syntastic#log#error("fail to startup server 5 times, disalbe async.")
            endif

            return
        endif
    endif

    try
        call remote_send(g:syntastic_async_servername, "<ESC>:call SyntasticServerDispatchHandler("
                    \ .message.")<CR>")
        " reset failure count if successful sending msg
        let s:total_startup_server_failures = 0
    catch /^Vim\%((\a\+)\)\=:E241/	" catch error E123
        call syntastic#log#error("Can't send message to server")
    endtry
endfunction

function! s:IsAsyncMake(signal)
    if type(a:signal) != type([]) || len(a:signal) != 1
        return 0
    endif
    let item = a:signal[0]
    return has_key(item, 'async') && item['async'] ==# 'async'
endfunction

function! s:PrepareCheckers(checker_list, aggregate_errors)
    " exit code check can be done on server, send them too.
    let checker_filetype_options_list = []

    if a:aggregate_errors
        let special_checker_number = 0
        let total_checker_number = 0
    else
        let special_checker_at_the_front = 0
    endif

    for checker in a:checker_list
        if !checker.isAvailable()
            " new syntastic has to explicitly check whether a checker is active
            continue
        endif

        " need to figure out whether special checkers exist, tell server.
        " special checker, for example ycm, cannot be run on server.

        let checker_name = checker.getName()
        let ft = checker.getFiletype()
        " this func will call modified SyntasticMake() then return back
        " checker's option, including makeprg, efm and other things.
        try
            let signal = checker.getLocListRaw()
        catch /^Vim\%((\a\+)\)\=:E/	" catch all Vim errors
            let err_msg = 'PrepareCheckers: '.checker_name.' throw an error: "'.v:exception.'" when extract checkers options. skip this checker.'
            call syntastic#log#error(err_msg)
            continue
        endtry

        let isAsyncMake = s:IsAsyncMake(signal)

        if !exists("b:syntastic_make_options")
            if isAsyncMake
                " isAsyncMake means SyntasticMake() is called, if
                " async is enabled and SyntasticMake() is called, there
                " must be a b:syntastic_make_options variable.
                echohl Error | echomsg "AsyncCacheErrors can't find make options" | echohl None
                continue
            endif

            " special checker here
            " only allow a checker which has non empty result get added
            if type(signal) == type([]) && !empty(signal)
                let sp_options = {'makeprg': 'sp', 'special_checker': 1, 'raw_errors': signal}
                if a:aggregate_errors
                    let special_checker_number += 1
                else
                    if empty(checker_filetype_options_list)
                        " this special checker is at the front of list
                        let special_checker_at_the_front = 1
                    endif
                endif
                call add(checker_filetype_options_list, [checker_name, ft, sp_options])
                if !a:aggregate_errors
                    " since new syntastic put all checkers into one list
                    " without considering their filetype. old beheaviour will
                    " roll other filetype but this time, no mater how many
                    " checkers' behide we know it will stop on this special
                    " checker index if previous checkers return nothing in non
                    " aggregate mode. it's new end index.
                    break
                endif
            endif
            continue
        endif

        if !isAsyncMake
            " most of checker directly return SyntasticMake()'s result,
            " but rare checkers will do somethings with that result.
            echohl Error | echomsg checker.getName()." modify async ".
                        \ "checker_options signal, most of time, ".
                        \ "this should not happen" | echohl None
            " TODO: may be we should terminal this checker?
        endif

        let checker_options = b:syntastic_make_options
        unlet b:syntastic_make_options

        let makeprg = get(checker_options, "makeprg", &l:makeprg)
        if empty(makeprg)
            let err_msg = checker_name.' has empty makeprg, strange!!!'
            echohl Error | echomsg err_msg | echohl None
            continue
        endif
        let checker_options['makeprg'] = makeprg

        let checker_options['errorformat'] = get(checker_options, "errorformat", &l:errorformat)

        " new syntastic use util#var
        let checker_quiet_messages = copy(syntastic#util#var(ft.'_'.checker_name . '_quiet_messages', {}))
        if type(checker_quiet_messages) == type({}) && !empty(checker_quiet_messages)
            let checker_options['quiet_messages'] = checker_quiet_messages
        endif

        call add(checker_filetype_options_list, [checker_name, ft, checker_options])
    endfor

    if empty(checker_filetype_options_list)
        " according to sync version, once syntastic check cmd is run,
        " even if there are no checkers, a emtpy result will always get
        " updated.
        " so we may simply update a empty result directly here.
        call s:UpdateEmptyLocListNow()
        return
    endif

    if a:aggregate_errors
        let total_checker_number = len(checker_filetype_options_list)
    endif

    if a:aggregate_errors && total_checker_number == special_checker_number
        " only special checkers in this round, directly update.
        call s:UpdateSpecialLocListNow(checker_filetype_options_list, a:aggregate_errors)
        return
    endif

    if !a:aggregate_errors && special_checker_at_the_front
        " the special checker at the front of checker list in every filetype,
        " directly update in this case.
        call s:UpdateSpecialLocListNow(checker_filetype_options_list, a:aggregate_errors)
        return
    endif

    let rpc_options = {}
    let rpc_options['long_fname'] = expand("%:p")
    let rpc_options['cwd'] = getcwd()
    let rpc_options['checker_filetype_options_list'] = checker_filetype_options_list
    if !empty(v:servername)
        " if v:servername is available, server can use remote_expr to fix
        " inconsistent bufnr in raw errors, then directly pass raw errors back
        " instead of system() output string.
        let rpc_options['client_name'] = v:servername
    endif
    let quiet_filters = copy(syntastic#util#var('quiet_messages', {}))
    if type(quiet_filters) == type({}) && !empty(quiet_filters)
        " global g:syntastic_quiet_messages, new syntastic do quite_messages
        " with checkers' together.
        let rpc_options['global_quiet_messages'] = quiet_filters
    endif
    let exit_checks = syntastic#util#var('exit_checks')
    let rpc_options['exit_checks'] = exit_checks

    let msg_header = a:aggregate_errors ? 'syntastic_aggregate' : 'syntastic'

    call s:RemoteSyntasticCheck(msg_header, rpc_options)
endfunction

function! s:UpdateSpecialLocListNow(checker_filetype_options_list, aggregate_errors)
    let info_map = {}
    let info_map['short_fname'] = bufname("%")
    let special_checker_map = {}
    let checker_ft_raw_errors_list = []
    for [checker_name, ft, sp_options] in a:checker_filetype_options_list
        call add(checker_ft_raw_errors_list, [checker_name, ft, sp_options['raw_errors']])
        let special_checker_map[checker_name] = 1
        if !a:aggregate_errors
            " non aggregate mode, we only need the makeprg at the front of each
            " list.
            break
        endif
    endfor

    let info_map['checker_ft_raw_errors_list'] = checker_ft_raw_errors_list
    let info_map['special_checkers'] = special_checker_map
    let newLoclist = s:Private_AsyncErrorPostProcess(info_map, a:aggregate_errors)
    call s:UpdateLocListInterfaceNow(newLoclist)
endfunction

function! s:UpdateEmptyLocListNow()
    call s:UpdateBufErrorsNumMap(bufname("%"), 0)
    call s:UpdateLocListInterfaceNow({})
endfunction

function! s:UpdateLocListInterfaceNow(loclist)
    let newLoclist = a:loclist
    if empty(a:loclist)
        let newLoclist = g:SyntasticLoclist.New([])
    endif
    let b:syntastic_async_loclist_already_refresh = 0
    if !g:syntastic_async_delay_error_refresh
        " TODO: s:RefreshErrors right now cause cursor move to other places like
        " sign column then wait a few second to restore and it can't be sovled
        " by setpos(). getpos() report the same value, it looks like a redraw
        " problem but calling s:Redraw() doesn't work.
        call s:RefreshErrors(newLoclist)
        " simulate Left and Right keypress, cursor can be restored faster.
        call feedkeys("\<Left>\<Right>")
        return
    endif
    " new syntastic use deploy()
    " let b:syntastic_loclist = newLoclist
    call newLoclist.deploy()
endfunction

let s:syntastic_buf_errors_num_map = {}
let s:syntastic_total_errors_num = 0
function! s:UpdateBufErrorsNumMap(fname, new_num)
    if empty(a:fname)
        return
    endif
    if has_key(s:syntastic_buf_errors_num_map, a:fname)
        let old_num = s:syntastic_buf_errors_num_map[a:fname]
        let s:syntastic_total_errors_num -= old_num
    endif
    let s:syntastic_total_errors_num += a:new_num
    let s:syntastic_buf_errors_num_map[a:fname] = a:new_num
endfunction
" since SyntasticStatuslineFlag func move to loclist.vim, there must be a func to get
" the private number.
function! GetTotalErrorNumInAsyncMode()
    return s:syntastic_total_errors_num
endfunction

" BufErrorList() show the buffer errors map list in preview window
function! s:BufErrorNumberList()
    let preview_name = "SyntasticErrorsPreviewList"
    "silent! exec "noautocmd botright pedit ".preview_name
    " botright put preview windows on bottom
    silent! exec "noautocmd pedit ".preview_name
    noautocmd wincmd p

    if &previewwindow               " check if we really got there
        set buftype=nofile
        " after preview window closed, delete preview buffer
        set bufhidden=delete
        call setline(1, "Bufnr    Buffer                    Errors")
        for [key, value] in items(s:syntastic_buf_errors_num_map)
            if value != 0
                " it's strange line("$") return 0 if i open preview window
                " on top.
                " b (0) b(10) e(35)
                let buf_line = bufnr(key)
                let buf_line = s:SpacesAlignHelper(buf_line, 9, key)
                let buf_line = s:SpacesAlignHelper(buf_line, 35, value)
                call append(line("w$"), buf_line)
            endif
        endfor
        set readonly
        noautocmd wincmd p			" back to old window
    endif
endfunction

" this function caculate the spaces needed between col and str end, if col is
" smaller than str len, it use 4 spaces. Append spaces then the str you want
" to append.
function! s:SpacesAlignHelper(str, col, append)
    let margin = a:col - strdisplaywidth(a:str)
    let spaces = repeat(' ', margin < 1 ? 4 : margin)
    return a:str.spaces.a:append
endfunction

if g:syntastic_enable_async
    command! BufErrNumList call s:BufErrorNumberList()
    " override reset command, update s:syntastic_buf_errors_num_map variable
    command! SyntasticReset call s:ClearCache() |
                \ call s:notifiers.refresh(g:SyntasticLoclist.New([])) |
                \ call s:UpdateBufErrorsNumMap(bufname("%"), 0)
endif

" current buf may not be the same one error checked, so we need to
" refresh that buf when we swtich to it.
"autocmd BufWinEnter * call s:NotifyErrors()
function! s:NotifyErrors()
    if exists("b:syntastic_async_post_process") &&
                \ exists("b:syntastic_async_aggregate_errors_flag")
        let info_map = b:syntastic_async_post_process
        let aggregate_errors = b:syntastic_async_aggregate_errors_flag
        unlet b:syntastic_async_post_process
        unlet b:syntastic_async_aggregate_errors_flag
        let newLoclist = s:Private_AsyncErrorPostProcess(info_map, aggregate_errors)
        " let b:syntastic_loclist = newLoclist
        call newLoclist.deploy()
    endif

    " don't call s:notifiers.refresh() on the same loclist multi time
    " otherwise %w parameters on statusline may not work correctly
    "
    " b:syntastic_loclist always be set if this buf call syntastic check
    " even bufname() not match, it's set by calling setbufvar()
    if empty(&bt) && exists("b:syntastic_async_loclist_already_refresh") &&
                \ !b:syntastic_async_loclist_already_refresh

        let loclist = g:SyntasticLoclist.current()

        call s:RefreshErrors(loclist)
    endif
endfunction

" NOTE: %w with sign enable have problem.
" SyntasticSignsNotifier._signErrors extend
" loclist._cachedWarnings without deepcopy().
" so warnings number on statusline always be the sum of warnings and errors.

" s:RefreshErrors() refresh current buf's errors
" It mainly copy the later half part of s:UpdateErrors(auto_invoked, ...).
function! s:RefreshErrors(loclist)
    " NOTE: s:ClearCache() will unlet b:syntastic_loclist so you must
    " set this variable before calling notifiers.refresh()
    "
    " only call this func on the buf who got errors refresh.
    "
    " previous i call this func too early even if bufname() not match
    " in AsyncUpdateErrors so currently lost sign, hightlight,
    " statusline so on.
    call s:ClearCache()

    " let b:syntastic_loclist = a:loclist
    call a:loclist.deploy()

    let loclist = g:SyntasticLoclist.current()

    " populate loclist and jump {{{3
    let do_jump = syntastic#util#var('auto_jump')
    if do_jump == 2
        let first = loclist.getFirstIssue()
        let type = get(first, 'type', '')
        let do_jump = type ==? 'E'
    endif

    let w:syntastic_loclist_set = 0
    if syntastic#util#var('always_populate_loc_list') || do_jump
        call syntastic#log#debug(g:_SYNTASTIC_DEBUG_NOTIFICATIONS, 'loclist: setloclist (new)')
        call setloclist(0, loclist.getRaw())
        let w:syntastic_loclist_set = 1
        if do_jump && !loclist.isEmpty()
            call syntastic#log#debug(g:_SYNTASTIC_DEBUG_NOTIFICATIONS, 'loclist: jump')
            silent! lrewind

            " XXX: Vim doesn't call autocmd commands in a predictible
            " order, which can lead to missing filetype when jumping
            " to a new file; the following is a workaround for the
            " resulting brain damage
            if &filetype == ''
                silent! filetype detect
            endif
        endif
    endif

    call s:notifiers.refresh(loclist)
    let b:syntastic_async_loclist_already_refresh = 1
endfunction

" this function set relate buf variable before refresh gui
fun! s:Private_PrepareAsyncPostProcess(info_map, aggregate_errors)
    let short_fname = a:info_map['short_fname']

    if bufname("%") !=# short_fname
        call setbufvar(short_fname, "syntastic_async_aggregate_errors_flag", a:aggregate_errors)
        call setbufvar(short_fname, "syntastic_async_post_process", a:info_map)
        call setbufvar(short_fname, "syntastic_async_loclist_already_refresh", 0)
        return
    endif

    let newLoclist = s:Private_AsyncErrorPostProcess(a:info_map, a:aggregate_errors)

    call s:UpdateLocListInterfaceNow(newLoclist)
endfunction

function! s:RemoteReplyMsgDispatcher(message)
    if empty(matchstr(a:message, 'syntastic'))
        return
    endif

    if match(a:message, '^syntastic@@@@') != -1
        call s:AsyncUpdateErrors(a:message)
    elseif match(a:message, '^syntastic_aggregate@@@@') != -1
        call s:AsyncUpdateAggregateErrors(a:message)
    elseif match(a:message, '^syntastic_warning_message@@@@') != -1
        let warning_str = split(a:message, '@@@@')[1]
        call syntastic#log#warn(warning_str)
    endif
endfunction

function! s:EchoExitMessage(msg_list)
    for [checker_name, filetype, exit_code] in a:msg_list
        call syntastic#log#error('checker ' . filetype . '/' . checker_name . ' returned abnormal status ' . exit_code)
    endfor
endfunction

function! s:EchoWarnMessage(msg_list)
    for msg in a:msg_list
        call syntastic#log#warn(msg)
    endfor
endfunction

" FixRawErrors try to fix wrong bufnr in raw errors which is right on server
" but wrong on client. it's used when client's v:servername is not found.
"
" TODO: will vim reasign a used bufnr to another files? for example, when max
" bufnr is reach? then vim collect bufnr started from 1.
function! s:FixRawErrors(raw_errors, bufnr_long_fname_map, wrong_right_bufnr_map)
    " try to use bufnr_long_fname_map to fix wrong bufnr in raw_errors
    let wrong_right_bufnr_map = copy(a:wrong_right_bufnr_map)
    let fixed_raw_errors = copy(a:raw_errors)
    for error in fixed_raw_errors
        let bufnr = error['bufnr']
        let valid = error['valid']

        if !valid
            continue
        endif

        if !has_key(wrong_right_bufnr_map, bufnr)
            if !has_key(a:bufnr_long_fname_map, bufnr)
                let err_msg = 'PreprocessServerMsg: a bufnr point to '.
                            \ 'non register filename, this cannot be happen.'
                call syntastic#log#error(err_msg)
                " this make error entry still valid and exists to the end
                let error['bufnr'] = 0
                continue
            endif

            let full_path_name = a:bufnr_long_fname_map[bufnr]
            let right_bufnr = bufnr(expand(full_path_name), 1)
            let wrong_right_bufnr_map[bufnr] = right_bufnr

            let error['bufnr'] = right_bufnr
            continue
        endif

        let error['bufnr'] = wrong_right_bufnr_map[bufnr]
    endfor

    return [fixed_raw_errors, wrong_right_bufnr_map]
endfunction

" call s:AsyncUpdateErrors() after RemoteReply event get syntastic result
function! s:AsyncUpdateErrors(message)
    call s:PreprocessServerMsg(a:message, 0)
endfunction

function! s:AsyncUpdateAggregateErrors(message)
    call s:PreprocessServerMsg(a:message, 1)
endfunction

function! s:PreprocessServerMsg(message, aggregate_errors)
    let options = s:SandboxEvalStr(s:SecureCheckOnMapStr(split(a:message, "@@@@")[1]))

    let long_fname = options['long_fname']
    " filetype use in checker postprocess, without filetype, you can't use
    " s:registry.getChecker() to obtain checker.
    let checker_ft_output_list = options['checker_ft_output_list']
    let exit_message_list = options['exit_message_list']
    let warn_msg_list = options['warn_msg_list']
    let short_fname = expand("#".bufnr(long_fname).":t")
    let sp_checker_map = options['sp_checker_map']
    let remain_ft_checkers_map = get(options, 'remain_ft_checkers_map', {})
    let remote_expr = get(options, 'remote_expr', 0)
    let bufnr_long_fname_map = get(options, 'bufnr_long_fname_map', {})

    if !empty(exit_message_list)
        call s:EchoExitMessage(exit_message_list)
    endif

    if !empty(warn_msg_list)
        call s:EchoWarnMessage(warn_msg_list)
    endif

    " abondan empty result early if there is not need to update
    if len(checker_ft_output_list) == 0 && has_key(s:syntastic_buf_errors_num_map, short_fname) &&
                \ s:syntastic_buf_errors_num_map[short_fname] == 0
        " empty result in previous round, empty result in this round too.
        " no need to refresh gui.
        return
    endif

    let result = {}
    let result['long_fname'] = long_fname
    let result['short_fname'] = short_fname
    let checker_ft_raw_errors_list = []
    let result['checker_ft_raw_errors_list'] = checker_ft_raw_errors_list
    " special checker raw_errors can be use directly, no postprocess.
    let result['special_checkers'] = copy(sp_checker_map)
    let result['remain_ft_checkers_map'] = remain_ft_checkers_map
    let error_num = 0

    " bufnr and fname map is same within a round of checking
    let wrong_right_bufnr_map = {}
    " server use remote_expr to fix wrong bufnr then pass raw_errors
    " direct.
    for [checker_name, filetype, raw_errors] in checker_ft_output_list
        " special checkers' result don't need to fix
        if !remote_expr && !has_key(sp_checker_map, checker_name)
            let [raw_errors, wrong_right_bufnr_map] = s:FixRawErrors(raw_errors, bufnr_long_fname_map, wrong_right_bufnr_map)
        endif

        call add(checker_ft_raw_errors_list, [checker_name, filetype, raw_errors])
        let error_num += len(raw_errors)
    endfor

    if error_num == 0 && has_key(s:syntastic_buf_errors_num_map, short_fname) &&
                \ s:syntastic_buf_errors_num_map[short_fname] == 0
        " empty result in previous round, empty valid result in this round too.
        " no need to refresh gui.
        return
    endif

    let result['checker_ft_raw_errors_list'] = checker_ft_raw_errors_list
    call s:UpdateBufErrorsNumMap(short_fname, error_num)
    call s:Private_PrepareAsyncPostProcess(result, a:aggregate_errors)
endfunction

function s:SecureCheckOnListStr(str)
    if !empty(a:str) && a:str[0] ==# '[' && a:str[len(a:str)-1] ==# ']'
        return a:str
    endif
    throw a:str." not a List string"
endfunction

function s:SecureCheckOnMapStr(str)
    if !empty(a:str) && a:str[0] ==# '{' && a:str[len(a:str)-1] ==# '}'
        return a:str
    endif
    throw a:str." not a Dictionary string"
endfunction

" eval() is danger, eval str inside a sandbox
function s:SandboxEvalStr(str)
    " dict_str will get wrapped by doublequote, so '\' and '"' must be escaped first
    let dict_str = escape(a:str, '\"')
    sandbox exec "let dict = eval(\"".dict_str."\")"
    return dict
endfunction

" this function return a checker list which after checker_name in the active
" checkers list. if no checker found, return a mepty list.
function! s:GetFollowingCheckers(remain_ft_checkers_map)
    let clist = []
    for [ft, checker_names] in items(a:remain_ft_checkers_map)
        call extend(clist, s:registry.getCheckers(ft, checker_names))
    endfor
    return clist
endfunction

function! s:DecorateAndSort(loclist, checker, cnames, if_decorate, if_sort)
    let cname = a:checker.getFiletype() . '/' . a:checker.getName()
    if a:if_decorate
        call a:loclist.decorate(cname)
    endif
    call add(a:cnames, cname)
    if a:checker.wantSort() && !a:if_sort
        call a:loclist.sort()
    endif

    return a:loclist
endfunction

" SyntasticMake and some plugins have a post process with error returned by
" makeprg.
"
" NOTE: this function should only be call on the buf match the id.
function! s:Private_AsyncErrorPostProcess(info_map, aggregate_errors)
    let checker_ft_raw_errors_list = a:info_map['checker_ft_raw_errors_list']
    let special_checker_map = a:info_map['special_checkers']
    let short_fname = a:info_map['short_fname']
    let remain_ft_checkers_map = a:info_map['remain_ft_checkers_map']
    let names = []
    if !a:aggregate_errors
        let following_checkers_list = []
    endif

    " new master version id feature, directly copy from CacheErrors() body
    " with slight modification.
    let decorate_errors = a:aggregate_errors && syntastic#util#var('id_checkers')
    let sort_aggregated_errors = a:aggregate_errors && syntastic#util#var('sort_aggregated_errors')

    let newLoclist = g:SyntasticLoclist.New([])
    for [checker_name, filetype, raw_errors] in checker_ft_raw_errors_list

        if has_key(special_checker_map, checker_name)
            " special checker has no postprocess, raw errors can be used
            " directly.
            let sp_list = g:SyntasticLoclist.New(raw_errors)
            let sp_checker = s:registry.getCheckers(filetype, [checker_name])[0]

            " special checker result here is already get gurantee to be non-empty.
            let newLoclist = newLoclist.extend(s:DecorateAndSort(sp_list,
                        \ sp_checker, names, decorate_errors, sort_aggregated_errors))
            continue
        endif

        let checker = s:registry.getCheckers(filetype, [checker_name])[0]

        let b:syntastic_async_raw_errors = raw_errors
        try
            let post_errors = checker.getLocList()
        catch /^Vim\%((\a\+)\)\=:E/	" catch all Vim errors
            let err_msg = 'AsyncErrorPostProcess: '.checker_name.
                        \ (a:aggregate_errors ? ' in aggregate mode' : '').
                        \ ' throw an error: '.v:exception
            call syntastic#log#error(err_msg)
        finally
            unlet b:syntastic_async_raw_errors
        endtry

        if !a:aggregate_errors
            " AsyncUpdateErrors() only count a list which has at least
            " one valid entry which's valid field is 1 as non-empty list.
            " so this time, a list after post process becomes an empty list
            " because it's entries really got cleared by post procedure.
            if post_errors.isEmpty()
                let following_checkers_list = s:GetFollowingCheckers(remain_ft_checkers_map)
                if !empty(following_checkers_list)
                    let t_warning = checker_name."'s postprocess delete all error entries, ".
                                \ "the checkers following this one will run."
                    echohl Error | echomsg t_warning | echohl None
                endif
            endif
        endif

        if !post_errors.isEmpty()
            let newLoclist = newLoclist.extend(s:DecorateAndSort(post_errors,
                        \ checker, names, decorate_errors, sort_aggregated_errors))
        endif
    endfor

    if !a:aggregate_errors && !empty(following_checkers_list)
        let b:syntastic_async_following_checkers_list = following_checkers_list
        call s:UpdateErrors(0)
        " keep old loclist
        return g:SyntasticLoclist.current()
    endif

    " directly copy from CacheErrors()
    if !empty(names)
        if len(syntastic#util#unique(map( copy(names), 'substitute(v:val, "\\m/.*", "", "")' ))) == 1
            let type = substitute(names[0], '\m/.*', '', '')
            let name = join(map( names, 'substitute(v:val, "\\m.\\{-}/", "", "")' ), ', ')
            call newLoclist.setName( name . ' ('. type . ')' )
        else
            " checkers from mixed types
            call newLoclist.setName(join(names, ', '))
        endif
    endif
    if sort_aggregated_errors
        call newLoclist.sort()
    endif

    " update real error number of this round
    call s:UpdateBufErrorsNumMap(short_fname, len(newLoclist.getRaw()))
    return newLoclist
endfunction
" client code above }}}
" -------------------------------



"refresh and redraw all the error info for this buf when saving or reading
function! s:UpdateErrors(auto_invoked, checker_names) " {{{2
    call syntastic#log#debugShowVariables(g:_SYNTASTIC_DEBUG_TRACE, 'version')
    call syntastic#log#debugShowOptions(g:_SYNTASTIC_DEBUG_TRACE, s:_DEBUG_DUMP_OPTIONS)
    call syntastic#log#debugDump(g:_SYNTASTIC_DEBUG_VARIABLES)
    call syntastic#log#debug(g:_SYNTASTIC_DEBUG_TRACE, 'UpdateErrors' . (a:auto_invoked ? ' (auto)' : '') .
        \ ': ' . (len(a:checker_names) ? join(a:checker_names) : 'default checkers'))
    if s:_skip_file()
        return
    endif

    call s:modemap.synch()
    let run_checks = !a:auto_invoked || s:modemap.doAutoChecking()
    if run_checks
        call s:CacheErrors(a:checker_names)
    endif

    if g:syntastic_enable_async
        " checker result handled by RemoteReply autocmd
        return
    endif

    let loclist = g:SyntasticLoclist.current()

    if exists('*SyntasticCheckHook')
        call SyntasticCheckHook(loclist.getRaw())
    endif

    " populate loclist and jump {{{3
    let do_jump = syntastic#util#var('auto_jump') + 0
    if do_jump == 2
        let do_jump = loclist.getFirstError(1)
    elseif do_jump == 3
        let do_jump = loclist.getFirstError()
    elseif 0 > do_jump || do_jump > 3
        let do_jump = 0
    endif

    let w:syntastic_loclist_set = 0
    if syntastic#util#var('always_populate_loc_list') || do_jump
        call syntastic#log#debug(g:_SYNTASTIC_DEBUG_NOTIFICATIONS, 'loclist: setloclist (new)')
        call setloclist(0, loclist.getRaw())
        let w:syntastic_loclist_set = 1
        if run_checks && do_jump && !loclist.isEmpty()
            call syntastic#log#debug(g:_SYNTASTIC_DEBUG_NOTIFICATIONS, 'loclist: jump')
            execute 'silent! lrewind ' . do_jump

            " XXX: Vim doesn't call autocmd commands in a predictible
            " order, which can lead to missing filetype when jumping
            " to a new file; the following is a workaround for the
            " resulting brain damage
            if &filetype == ''
                silent! filetype detect
            endif
        endif
    endif
    " }}}3

    call s:notifiers.refresh(loclist)
endfunction " }}}2

"clear the loc list for the buffer
function! s:ClearCache() " {{{2
    call s:notifiers.reset(g:SyntasticLoclist.current())
    call b:syntastic_loclist.destroy()
endfunction " }}}2

"detect and cache all syntax errors in this buffer
function! s:CacheErrors(checker_names) " {{{2
    call syntastic#log#debug(g:_SYNTASTIC_DEBUG_TRACE, 'CacheErrors: ' .
        \ (len(a:checker_names) ? join(a:checker_names) : 'default checkers'))
    call s:ClearCache()
    let newLoclist = g:SyntasticLoclist.New([])

    if !s:_skip_file()
        " debug logging {{{3
        call syntastic#log#debugShowVariables(g:_SYNTASTIC_DEBUG_TRACE, 'aggregate_errors')
        call syntastic#log#debug(g:_SYNTASTIC_DEBUG_TRACE, 'getcwd() = ' . getcwd())
        " }}}3

        let filetypes = s:_resolve_filetypes([])
        let aggregate_errors = syntastic#util#var('aggregate_errors') || len(filetypes) > 1
        let decorate_errors = aggregate_errors && syntastic#util#var('id_checkers')
        let sort_aggregated_errors = aggregate_errors && syntastic#util#var('sort_aggregated_errors')

        " new syntastic implement hold all checkers in one list
        if g:syntastic_enable_async
            if !has('clientserver')
                call syntastic#log#warn('clientserver feature missing, async disable')
                let g:syntastic_enable_async = 0
            endif
        endif

        let clist = []
        if g:syntastic_enable_async
            let following_checkers_filled = 0
            if exists("b:syntastic_async_following_checkers_list")
                call extend(clist, b:syntastic_async_following_checkers_list)
                unlet b:syntastic_async_following_checkers_list
                let following_checkers_filled = 1
            endif
        endif
        for type in filetypes
            if g:syntastic_enable_async && following_checkers_filled
                break
            endif

            call extend(clist, s:registry.getCheckers(type, a:checker_names))
        endfor

        let names = []
        let unavailable_checkers = 0
        for checker in clist
            if g:syntastic_enable_async && following_checkers_filled
                " run remaining checkers don't need to calculate unavailable_checkers again
                break
            endif

            let cname = checker.getFiletype() . '/' . checker.getName()
            if !checker.isAvailable()
                call syntastic#log#debug(g:_SYNTASTIC_DEBUG_TRACE, 'CacheErrors: Checker ' . cname . ' is not available')
                let unavailable_checkers += 1
                continue
            endif

            if g:syntastic_enable_async
                " new syntastic s:registry.getCheckers() will not filter no active checkers.
                " loop to calculate unavailable_checkers to make warning below work.
                continue
            endif

            call syntastic#log#debug(g:_SYNTASTIC_DEBUG_TRACE, 'CacheErrors: Invoking checker: ' . cname)

            let loclist = checker.getLocList()

            if !loclist.isEmpty()
                if decorate_errors
                    call loclist.decorate(cname)
                endif
                call add(names, cname)
                if checker.wantSort() && !sort_aggregated_errors
                    call loclist.sort()
                    call syntastic#log#debug(g:_SYNTASTIC_DEBUG_LOCLIST, 'sorted:', loclist)
                endif

                let newLoclist = newLoclist.extend(loclist)

                if !aggregate_errors
                    break
                endif
            endif
        endfor

        " in async mode, names is alwasy empty.
        " set names {{{3
        if !empty(names)
            if len(syntastic#util#unique(map( copy(names), 'substitute(v:val, "\\m/.*", "", "")' ))) == 1
                let type = substitute(names[0], '\m/.*', '', '')
                let name = join(map( names, 'substitute(v:val, "\\m.\\{-}/", "", "")' ), ', ')
                call newLoclist.setName( name . ' ('. type . ')' )
            else
                " checkers from mixed types
                call newLoclist.setName(join(names, ', '))
            endif
        endif
        " }}}3

        " issue warning about no active checkers {{{3
        if len(clist) == unavailable_checkers
            if !empty(a:checker_names)
                if len(a:checker_names) == 1
                    call syntastic#log#warn('checker ' . a:checker_names[0] . ' is not available')
                else
                    call syntastic#log#warn('checkers ' . join(a:checker_names, ', ') . ' are not available')
                endif
            else
                call syntastic#log#debug(g:_SYNTASTIC_DEBUG_TRACE, 'CacheErrors: no checkers available for ' . &filetype)
            endif
        endif
        " }}}3

        if g:syntastic_enable_async
            " non async version will update an empty loclist.
            " here calling PrepareCheckers() with empty map will
            " result in updating an empty loclist too.
            "
            " Update: new syntastic has to explicitly check whether a checker is active.
            " registry.getCheckers() will not filter for you. so empty(clist) doesn't
            " work anymore.
            if len(clist) == unavailable_checkers
                return
            endif

            if !empty(a:checker_names)
                " if user specify a checker name, it acts like aggregate mode
                " with only one checker.
                let aggregate_errors = 1
            endif
            call s:PrepareCheckers(clist, aggregate_errors)
            return
        endif
        call syntastic#log#debug(g:_SYNTASTIC_DEBUG_LOCLIST, 'aggregated:', newLoclist)
        if sort_aggregated_errors
            call newLoclist.sort()
            call syntastic#log#debug(g:_SYNTASTIC_DEBUG_LOCLIST, 'sorted:', newLoclist)
        endif
    endif

    call newLoclist.deploy()
endfunction " }}}2

"Emulates the :lmake command. Sets up the make environment according to the
"options given, runs make, resets the environment, returns the location list
"
"a:options can contain the following keys:
"    'makeprg'
"    'errorformat'
"
"The corresponding options are set for the duration of the function call. They
"are set with :let, so dont escape spaces.
"
"a:options may also contain:
"   'defaults' - a dict containing default values for the returned errors
"   'subtype' - all errors will be assigned the given subtype
"   'preprocess' - a function to be applied to the error file before parsing errors
"   'postprocess' - a list of functions to be applied to the error list
"   'cwd' - change directory to the given path before running the checker
"   'env' - environment variables to set before running the checker
"   'returns' - a list of valid exit codes for the checker
" @vimlint(EVL102, 1, l:env_save)
function! SyntasticMake(options) " {{{2
    call syntastic#log#debug(g:_SYNTASTIC_DEBUG_TRACE, 'SyntasticMake: called with options:', a:options)

    let errors = []
    if g:syntastic_enable_async && !exists("b:syntastic_async_raw_errors")
        let b:syntastic_make_options = a:options
        " async return empty error list here
        " currently don't suppor plugin checkers' self afterward process
        " make a fake error list, otherwise quiet messages will complain
        " missing key.
        return [{"async": "async", "text": "", "type": "", "bufnr": 0, 'lnum': 0, 'col': 0, 'valid': 1, 'vcol': 0, 'nr': -1, 'pattern': ''}]
    endif

    if exists("b:syntastic_async_raw_errors")
        return s:PostMake(b:syntastic_async_raw_errors, a:options)
    endif

    " save options and locale env variables {{{3
    let old_shellredir = &shellredir
    let old_local_errorformat = &l:errorformat
    let old_errorformat = &errorformat
    let old_cwd = getcwd()
    let old_lc_messages = $LC_MESSAGES
    let old_lc_all = $LC_ALL
    " }}}3

    call s:_bash_hack()

    if has_key(a:options, 'errorformat')
        let &errorformat = a:options['errorformat']
    endif

    if has_key(a:options, 'cwd')
        execute 'lcd ' . fnameescape(a:options['cwd'])
    endif

    " set environment variables {{{3
    let env_save = {}
    if has_key(a:options, 'env') && len(a:options['env'])
        for key in keys(a:options['env'])
            if key =~? '\m^[a-z_]\+$'
                exec 'let env_save[' . string(key) . '] = $' . key
                exec 'let $' . key . ' = ' . string(a:options['env'][key])
            endif
        endfor
    endif
    let $LC_MESSAGES = 'C'
    let $LC_ALL = ''
    " }}}3

    let err_lines = split(system(a:options['makeprg']), "\n", 1)

    " restore environment variables {{{3
    let $LC_ALL = old_lc_all
    let $LC_MESSAGES = old_lc_messages
    if len(env_save)
        for key in keys(env_save)
            exec 'let $' . key . ' = ' . string(env_save[key])
        endfor
    endif
    " }}}3

    call syntastic#log#debug(g:_SYNTASTIC_DEBUG_LOCLIST, 'checker output:', err_lines)

    " Does it still make sense to go on?
    let bailout =
        \ syntastic#util#var('exit_checks') &&
        \ has_key(a:options, 'returns') &&
        \ index(a:options['returns'], v:shell_error) == -1

    if !bailout
        if has_key(a:options, 'Preprocess')
            let err_lines = call(a:options['Preprocess'], [err_lines])
            call syntastic#log#debug(g:_SYNTASTIC_DEBUG_LOCLIST, 'preprocess (external):', err_lines)
        elseif has_key(a:options, 'preprocess')
            let err_lines = call('syntastic#preprocess#' . a:options['preprocess'], [err_lines])
            call syntastic#log#debug(g:_SYNTASTIC_DEBUG_LOCLIST, 'preprocess:', err_lines)
        endif
        lgetexpr err_lines

        let errors = deepcopy(getloclist(0))

        if has_key(a:options, 'cwd')
            execute 'lcd ' . fnameescape(old_cwd)
        endif

        try
            silent lolder
        catch /\m^Vim\%((\a\+)\)\=:E380/
            " E380: At bottom of quickfix stack
            call setloclist(0, [], 'r')
        catch /\m^Vim\%((\a\+)\)\=:E776/
            " E776: No location list
            " do nothing
        endtry
    else
        let errors = []
    endif

    " restore options {{{3
    let &errorformat = old_errorformat
    let &l:errorformat = old_local_errorformat
    let &shellredir = old_shellredir
    " }}}3

    if !s:_running_windows && (s:_os_name() =~ "FreeBSD" || s:_os_name() =~ "OpenBSD")
        call syntastic#util#redraw(g:syntastic_full_redraws)
    endif

    if bailout
        throw 'Syntastic: checker error'
    endif

    return s:PostMake(errors, a:options)
endfunction

" split SyntasticMake so merge from master don't cause much diff code because
" of if-else code block spaces format.
function! s:PostMake(errors, options)
    let errors = a:errors

    call syntastic#log#debug(g:_SYNTASTIC_DEBUG_LOCLIST, 'raw loclist:', errors)

    if has_key(a:options, 'defaults')
        call s:_add_to_errors(errors, a:options['defaults'])
    endif

    " Add subtype info if present.
    if has_key(a:options, 'subtype')
        call s:_add_to_errors(errors, { 'subtype': a:options['subtype'] })
    endif

    if has_key(a:options, 'Postprocess') && !empty(a:options['Postprocess'])
        for rule in a:options['Postprocess']
            let errors = call(rule, [errors])
        endfor
        call syntastic#log#debug(g:_SYNTASTIC_DEBUG_LOCLIST, 'postprocess (external):', errors)
    elseif has_key(a:options, 'postprocess') && !empty(a:options['postprocess'])
        for rule in a:options['postprocess']
            let errors = call('syntastic#postprocess#' . rule, [errors])
        endfor
        call syntastic#log#debug(g:_SYNTASTIC_DEBUG_LOCLIST, 'postprocess:', errors)
    endif

    return errors
endfunction " }}}2
" @vimlint(EVL102, 0, l:env_save)

"return a string representing the state of buffer according to
"g:syntastic_stl_format
"
"return '' if no errors are cached for the buffer
function! SyntasticStatuslineFlag() " {{{2
    return g:SyntasticLoclist.current().getStatuslineFlag()
endfunction " }}}2

" }}}1

" Utilities {{{1

function! s:_resolve_filetypes(filetypes) " {{{2
    let type = len(a:filetypes) ? a:filetypes[0] : &filetype
    return split( get(g:syntastic_filetype_map, type, type), '\m\.' )
endfunction " }}}2

function! s:_ignore_file(filename) " {{{2
    let fname = fnamemodify(a:filename, ':p')
    for pattern in g:syntastic_ignore_files
        if fname =~# pattern
            return 1
        endif
    endfor
    return 0
endfunction " }}}2

" Skip running in special buffers
function! s:_skip_file() " {{{2
    let fname = expand('%', 1)
    let skip = get(b:, 'syntastic_skip_checks', 0) || (&buftype != '') ||
        \ !filereadable(fname) || getwinvar(0, '&diff') || s:_ignore_file(fname) ||
        \ fnamemodify(fname, ':e') =~? g:syntastic_ignore_extensions
    if skip
        call syntastic#log#debug(g:_SYNTASTIC_DEBUG_TRACE, '_skip_file: skipping checks')
    endif
    return skip
endfunction " }}}2

" Explain why checks will be skipped for the current file
function! s:_explain_skip(filetypes) " {{{2
    if empty(a:filetypes) && s:_skip_file()
        let why = []
        let fname = expand('%', 1)

        if get(b:, 'syntastic_skip_checks', 0)
            call add(why, 'b:syntastic_skip_checks set')
        endif
        if &buftype != ''
            call add(why, 'buftype = ' . string(&buftype))
        endif
        if !filereadable(fname)
            call add(why, 'file not readable / not local')
        endif
        if getwinvar(0, '&diff')
            call add(why, 'diff mode')
        endif
        if s:_ignore_file(fname)
            call add(why, 'filename matching g:syntastic_ignore_files')
        endif
        if fnamemodify(fname, ':e') =~? g:syntastic_ignore_extensions
            call add(why, 'extension matching g:syntastic_ignore_extensions')
        endif

        echomsg 'The current file will not be checked (' . join(why, ', ') . ')'
    endif
endfunction " }}}2

" Take a list of errors and add default values to them from a:options
function! s:_add_to_errors(errors, options) " {{{2
    for err in a:errors
        for key in keys(a:options)
            if !has_key(err, key) || empty(err[key])
                let err[key] = a:options[key]
            endif
        endfor
    endfor

    return a:errors
endfunction " }}}2

" XXX: Is this still needed?
" The script changes &shellredir to stop the screen
" flicking when shelling out to syntax checkers.
function! s:_bash_hack() " {{{2
    if g:syntastic_bash_hack
        if !exists('s:shell_is_bash')
            let s:shell_is_bash =
                \ !s:_running_windows &&
                \ (s:_os_name() !~# "FreeBSD") && (s:_os_name() !~# "OpenBSD") &&
                \ &shell =~# '\m\<bash$'
        endif

        if s:shell_is_bash
            let &shellredir = '&>'
        endif
    endif
endfunction " }}}2

function! s:_os_name() " {{{2
    if !exists('s:_uname')
        let s:_uname = system('uname')
        lockvar s:_uname
    endif
    return s:_uname
endfunction " }}}2

" }}}1

" vim: set sw=4 sts=4 et fdm=marker:
