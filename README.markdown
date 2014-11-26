a async version of syntastic use vim's clientserver feature

update to latest master commit 67ffe58818

echo has('clientserver') should return 1

to enable async mode

```vim
let g:syntastic_enable_async = 1
```

right now, gvim and vim can be used as sever.

if vim is used, then it will be wrapped by gnome-terminal or tmux.
by default, if you inside a tmux, then create server inside tmux too.

```vim
let g:syntastic_async_tmux_if_possible = 1
```

this will create vim server in number 9 window in tmux

```vim
let g:syntastic_async_tmux_new_window = 1
```

if gvim or gnome-terminal is used, you can install xwit to automatically
minimized popup window.

You may add
%EI{, }%T{Tal: #%Tn}
to your g:syntastic_stl_format, this will display total errors and warnings
number across buffers.

===========================================


syntastic的异步版本，使用clientserver功能

echo has('clientsever')必须返回1确认clientserver功能被编译进去

开启异步
```vim
let g:syntastic_enable_async = 1
```

支持gvim和vim作为异步服务器使用

如果使用vim作为服务器，则通过gnome-terminal或者tmux来启动它
如果你已经在tmux环境下，则默认在tmux内启动vim服务器

```vim
let g:syntastic_async_tmux_if_possible = 1
```

在编号为9的窗口里启动vim服务器

```vim
let g:syntastic_async_tmux_new_window = 1
```

如果使用gnome-terminal或者gvim，那么可以安装xwit来自动最小化弹出的窗口

你也可以添加
%EI{, }%T{Tal: #%Tn}
到你的g:syntastic_stl_format，它会显示全局的错误和警告数量。

<!--
vim:tw=79:sw=4:
-->
