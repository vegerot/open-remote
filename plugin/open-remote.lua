--- PLUGIN
local function strip_trailing_newline(str)
	if (string.sub(str, string.len(str)) == "\n") then
		return string.sub(str, 0, string.len(str) - 1)
	end
	return str
end

local function sl(cmd, cwd)
	return strip_trailing_newline(vim.fn.system("sl --cwd=" .. cwd .. " " .. cmd ))
end

local function get_params(line1, line2)
	local absolute_filepath = vim.fn.expand("%:p")
	local absolute_directory_path = vim.fn.expand("%:p:h")
	local repo_root = sl('root', absolute_directory_path)
	local line_number_start = line1 and line1 or vim.fn.line(".")
	--NOTE: use the range argument instead
	local line_number_end = line2

	local os = strip_trailing_newline(vim.fn.system("uname"))
	-- TODO: prompt if multiple paths (or just use `default`?)
	-- TODO: support git
	local remote_path = sl("paths default", absolute_directory_path)
	local sapling_remotebookmark_template = 'word(0,sub("\\w+/", "", remotebookmarks))'
	-- use the remote branch name if it exists, otherwise use the commit hash
	local sapling_ref_template = '{ifeq(remotebookmarks, "", "{node}",' .. sapling_remotebookmark_template .. ' )}'
	-- TODO: check if commit is pushed, and if not fall back to `main` branch
	local ref = sl('log -r . -T \'' .. sapling_ref_template .. "'", absolute_directory_path)

	return { ref = ref, repo_root = repo_root, line_number_start = line_number_start, line_number_end = line_number_end, os = os, remote_path = remote_path,
		absolute_filepath = absolute_filepath }
end

local function get_repo_url_from_sl_path (path)
	local function trim_to(str, pattern)
		local start = string.find(str, pattern)
		if start then
			return string.sub(str, start + string.len(pattern))
		end
		return str
	end

	local repo_url = path
	repo_url = trim_to(repo_url, "://")
	repo_url = trim_to(repo_url, "git@")

	-- calculating the length of this pattern ("%.git") is non-trivial
	-- and it's only used once so do it the long way
	local repo_url_end = string.find(repo_url, "%.git")
	if repo_url_end then
		repo_url = string.sub(repo_url, 0, repo_url_end - 1)
	end
	return repo_url
end

function Open_File_Cmd(params)
	local open_cmd = "open"
	local os = params.os
	if os == "Linux" then
		open_cmd = "xdg-open"
	end

	local url = Get_remote_file_url(params)

	return open_cmd .. " '" .. url .. "'"
end

function Copy_File_Cmd(params)
	local copy_cmd = "pbcopy"
	local os = params.os
	if os == "Linux" then
		copy_cmd = "xclip -selection clipboard"
	end

	local url = Get_remote_file_url(params)

	return "printf '" .. url .. "' | " .. copy_cmd
end

function Get_remote_file_url(params)
	local absolute_filepath = params.absolute_filepath
	local repo_root = params.repo_root
	local line_number_start = params.line_number_start
	local line_number_end = params.line_number_end
	local remote_path = params.remote_path
	local ref = params.ref

	local relative_filepath = string.sub(absolute_filepath, string.len(repo_root) + 2)

	local line_number_fragment = "#L" .. line_number_start
	if line_number_end then
		line_number_fragment = line_number_fragment .. "-L" .. line_number_end
	end

	local url = vim.fn.fnameescape("https://" ..
		get_repo_url_from_sl_path(remote_path) .. "/blob/" .. ref .. "/" .. relative_filepath .. line_number_fragment
	)
	return url
end

function Get_open_file_cmd(line1, line2)
	local params = get_params(line1, line2)
	return Open_File_Cmd(params)
end

function Get_copy_file_cmd(line1, line2)
	local params = get_params(line1, line2)
	return Copy_File_Cmd(params)
end

function Open_file(lines)
	local cmd = Get_open_file_cmd(lines.line1, lines.line2)
	vim.cmd("!" .. cmd)
end
vim.api.nvim_create_user_command("OpenFile", Open_file, {range = true, nargs=0})

function Copy_file(lines)
	local cmd = Get_copy_file_cmd(lines.line1, lines.line2)
	vim.cmd("!" .. cmd)
end
vim.api.nvim_create_user_command("CopyFile", Copy_file, {range = true })

--- TESTS
local function test_get_repo_url_from_remote_path()
	Assert_equals(get_repo_url_from_sl_path("ssh://git@gecgithub01.walmart.com/ce-orchestration/ce-smartlists.git"), "gecgithub01.walmart.com/ce-orchestration/ce-smartlists")
	Assert_equals(get_repo_url_from_sl_path("https://github.com/facebook/sapling.git"), "github.com/facebook/sapling")
end

local function test_open_file_helper()
	local cmd = Open_File_Cmd({ absolute_filepath = "~/dotfiles/.config/nvim/lua/open-remote.lua",
		repo_root = "~/dotfiles", line_number_start = 69, os = "Darwin", remote_path = "git@github.com/vegerot/dotfiles",
		ref = "main" })
	Assert_equals(cmd, "open 'https://github.com/vegerot/dotfiles/blob/main/.config/nvim/lua/open-remote.lua\\#L69'")

	local cmd2 = Open_File_Cmd({ absolute_filepath = "~/workspace/gitlab.com/gitlab-org/gitlab/.gitlab/CODEOWNERS",
		line_number_start = 42, repo_root = "~/workspace/gitlab.com/gitlab-org/gitlab", os = "Linux",
		remote_path = "https://gitlab.com/gitlab-org/gitlab.git", ref = "79da4d8f" })
	Assert_equals(cmd2, "xdg-open 'https://gitlab.com/gitlab-org/gitlab/blob/79da4d8f/.gitlab/CODEOWNERS\\#L42'")

	-- visual line range
	local cmd3 = Open_File_Cmd({ absolute_filepath = "~/dotfiles/.config/nvim/lua/open-remote.lua",
		repo_root = "~/dotfiles", line_number_start = 42, line_number_end = 69, os = "Darwin", remote_path = "git@github.com/vegerot/dotfiles",
		ref = "main" })
	Assert_equals(cmd3, "open 'https://github.com/vegerot/dotfiles/blob/main/.config/nvim/lua/open-remote.lua\\#L42-L69'")
end

local function test_copy_file_helper()
	local cmd = Copy_File_Cmd({ absolute_filepath = "~/dotfiles/.config/nvim/lua/open-remote.lua",
		repo_root = "~/dotfiles", line_number_start = 69, os = "Linux", remote_path = "git@github.com/vegerot/dotfiles",
		ref = "main" })
	Assert_equals(cmd, "printf 'https://github.com/vegerot/dotfiles/blob/main/.config/nvim/lua/open-remote.lua\\#L69' | xclip -selection clipboard")

	local cmd2 = Copy_File_Cmd({ absolute_filepath = "~/dotfiles/.config/nvim/lua/open-remote.lua",
		repo_root = "~/dotfiles", line_number_start = 69, os = "Darwin", remote_path = "git@github.com/vegerot/dotfiles",
		ref = "main" })
	Assert_equals(cmd2, "printf 'https://github.com/vegerot/dotfiles/blob/main/.config/nvim/lua/open-remote.lua\\#L69' | pbcopy")

end

-- run with `open-remote-test` script
local function e2e_test()
	local cmd = Get_open_file_cmd()
	Assert_equals(cmd,  "xdg-open 'https://github.com/testuser/testrepo/blob/main/foo.txt\\#L2'")
	-- for some reason neovim (libuv in particular) crashes when using `vim.cmd("quit")`
	os.exit()
end
vim.api.nvim_create_user_command("OpenRemoteTestE2e", e2e_test, {nargs=0})

-- run with `open-remote-test` script
local function e2e_test_2()
	local cmd = Get_open_file_cmd()
	local want = "xdg--open 'https://github.com/testuser/testrepo/blob/(%x+)/foo.txt\\#L2'"
	local _, _, maybe_match = string.find(cmd, want)
	assert(maybe_match ~= nil)
	Assert_equals(string.len(maybe_match), 40)

	os.exit()
end
vim.api.nvim_create_user_command("OpenRemoteTestE2e2", e2e_test_2, {nargs=0})

-- run with `open-remote-test` script
local function e2e_test_visual_select_range(lines)
	local cmd = Get_open_file_cmd(lines.line1, lines.line2)
	Assert_equals(cmd,  "xdg-open 'https://github.com/testuser/testrepo/blob/main/foo.txt\\#L2-L4'")
	-- for some reason neovim (libuv in particular) crashes when using `vim.cmd("quit")`
	os.exit()

end
vim.api.nvim_create_user_command("OpenRemoteTestE2eVisualSelectRange", e2e_test_visual_select_range, {nargs=0, range=true})


-- run tests automatically: `nmap <leader>t :w \| source % \| OpenRemoteTest <CR>`
local function test()
	test_get_repo_url_from_remote_path()
	test_open_file_helper()
	test_copy_file_helper()
	print("✅")
end
-- jank: run tests with `:w | source % | OpenRemoteTest`
vim.api.nvim_create_user_command("OpenRemoteTest", test, {nargs=0})
function Open_Remote_Test()
	test()
	os.exit()
end

function Assert_equals(got, want)
	if got ~= want then
		print("\nExpected: " .. want .. "\n Actual: " .. got)
		assert(false)
	end
end

