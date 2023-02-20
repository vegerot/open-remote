# Open Remote.vim

**open-remote** is a Neovim plugin to open the current file in your VCS
    web UI (i.e. GitHub.com).

Currently, only works with [Sapling](https://github.com/facebook/sapling).  Git
support coming 🔜

Inspired by [ruanyl/vim-gh-line](https://github.com/ruanyl/vim-gh-line)

## Installation
### manual
1. clone this repo into your runtimepath (e.g. `~/.local/share/nvim/site/pack/external/start/`)

```sh
$ mkdir -p ~/.local/share/nvim/site/pack/external/start/
$ clone ssh://git@github.com/vegerot/open-remote ~/.local/share/nvim/site/pack/external/start/open-remote
```

2. Add a shortcut for this command in your `init.vim`:

```vim
nmap <leader>op :OpenFile
```

### vim-plug
1. Install vim-plug
2. add to your plugins in `init.vim`

```vim
Plug 'vegerot/open-remote'
```



## Developing
```sh
$ nvim open-remote.lua
" run tests
:w | source % | OpenRemoteTest
" no output = ✅
```

to develop open-remote, you can quickly iterate by
```sh
$ nvim open-remote.lua
" make some change
:w | source %
:OpenRepo
" web browser should open to https://github.com/vegerot/dotfiles (or wherever you put this file)
```

## TODO
- add `CopyFile` (which copies the URL)
- detect if `ref` is pushed to remote.  If not, then find the most recent
  ref/branch that has been pushed and use that instead
- support git
- choose remote
- Windows support
- customize how to open browser (e.g. default browser)
- `OpenBlame`

## Better project names
- OpenTheSource
- ForkShare
