-- ~/.config/nvim/init.lua  (successor to ~/.vimrc.old, built on mini.nvim)
vim.g.mapleader = ';'

-- Bootstrap mini.nvim so mini.deps manages it ---------------------------------
local path_package = vim.fn.stdpath('data') .. '/site/'
local mini_path = path_package .. 'pack/deps/start/mini.nvim'
if not vim.uv.fs_stat(mini_path) then
  vim.cmd('echo "Installing mini.nvim" | redraw')
  vim.fn.system({ 'git', 'clone', '--filter=blob:none', 'https://github.com/nvim-mini/mini.nvim', mini_path })
  vim.cmd('packadd mini.nvim | helptags ALL')
end
require('mini.deps').setup({ path = { package = path_package } })
local add, now, later = MiniDeps.add, MiniDeps.now, MiniDeps.later

-- Sanity (vim-sensible -> mini.basics, plus the old explicit settings) -------
now(function()
  require('mini.basics').setup({ options = { extra_ui = true }, mappings = { windows = true } })
  local o = vim.o
  o.shell = '/bin/zsh'
  o.expandtab, o.tabstop, o.softtabstop, o.shiftwidth = true, 2, 2, 2
  o.textwidth = 0
  o.spell = false
  o.clipboard = 'unnamedplus'
  -- Black Metal (matches ~/.config/ghostty/config); base02 = selection, base03 = comments
  require('mini.base16').setup({ palette = {
    base00 = '#000000', base01 = '#121212', base02 = '#333333', base03 = '#5a5a5a',
    base04 = '#999999', base05 = '#c1c1c1', base06 = '#999999', base07 = '#c1c1c1',
    -- 09 / 0C / 0D / 0E were greys (functions, keywords, constants hard to tell apart); now accents borrowed
    -- from the Black Metal variants: Nile taupe, the variants' shared teal, Immortal blue, Burzum sage.
    base08 = '#486e6f', base09 = '#aa9988', base0A = '#a06666', base0B = '#dd9999',
    base0C = '#5f8787', base0D = '#7799bb', base0E = '#99bbaa', base0F = '#444444',
  } })
  vim.g.colors_name = 'blackmetal'
end)

-- UI: buftabline -> mini.tabline, lightline -> mini.statusline ---------------
now(function()
  require('mini.icons').setup()
  MiniIcons.mock_nvim_web_devicons() -- nvim-tree icons; needs a Nerd Font
  require('mini.tabline').setup()
  require('mini.statusline').setup()
end)

-- Buffers: same mappings as before; mini.bufremove keeps the layout intact ----
now(function()
  -- nvim-treesitter (main branch: needs nvim 0.12 + `brew install tree-sitter-cli`) installs extra parsers;
  -- html lets render-markdown hide <a>/<p>/... tags. install() is async and skips parsers already present.
  add({ source = 'nvim-treesitter/nvim-treesitter', checkout = 'main', hooks = { post_checkout = function() vim.cmd('TSUpdate') end } })
  require('nvim-treesitter').install({ 'html' })
  -- Treesitter markdown in .md and octo buffers (render-markdown needs it; octo's conceallevel=2 hides **, `, URLs).
  -- Set up at startup so `nvim README.md` gets it too.
  vim.treesitter.language.register('markdown', 'octo')
  vim.api.nvim_create_autocmd('FileType', { pattern = { 'markdown', 'octo' }, callback = function(ev) pcall(vim.treesitter.start, ev.buf) end })
  require('mini.bufremove').setup()
  local map = vim.keymap.set
  map('n', '<leader>l', '<cmd>bnext<cr>')
  map('n', '<leader>h', '<cmd>bprev<cr>')
  map('n', '<leader>j', function() MiniBufremove.delete() end)
  map('n', '<C-n>', '<cmd>bnext<cr>')
  map('n', '<C-p>', '<cmd>bprev<cr>')
  map('t', '<Esc><Esc>', [[<C-\><C-n>]])

  -- tmux-style window prefix, mirrors ~/.tmux.conf (works from the terminal window too)
  local function wmap(lhs, rhs) map({ 'n', 't' }, '<C-a>' .. lhs, rhs) end
  for key, dir in pairs({ Left = 'h', Down = 'j', Up = 'k', Right = 'l' }) do
    wmap('<' .. key .. '>', '<Cmd>wincmd ' .. dir .. '<CR>')
    wmap(dir, '<Cmd>wincmd ' .. dir .. '<CR>')
  end
  wmap('<C-Left>', '<Cmd>vertical resize -2<CR>')
  wmap('<C-Right>', '<Cmd>vertical resize +2<CR>')
  wmap('<C-Up>', '<Cmd>resize -2<CR>')
  wmap('<C-Down>', '<Cmd>resize +2<CR>')
  wmap('v', '<Cmd>vsplit<CR>')
  wmap('b', '<Cmd>split<CR>')
  wmap('<C-a>', '<Cmd>wincmd p<CR>') -- tmux: last-window
  wmap('a', '<C-a>')                 -- tmux: send-prefix (increment / bash line-start)
end)

-- Language support: native LSP (replaces ALE/jedi/deoplete/OmniCppComplete) --
now(function()
  require('mini.completion').setup()
  add('neovim/nvim-lspconfig')
  vim.lsp.config('*', { capabilities = MiniCompletion.get_lsp_capabilities() })
  vim.lsp.enable({ 'pyright', 'zls', 'clangd', 'ts_ls', 'gopls' })
  vim.diagnostic.config({ virtual_text = true, severity_sort = true }) -- E beats W when a line has both
  -- mini.base16 colours errors with base08, which is red in most base16 themes but teal in Black Metal (the
  -- staged colour). Errors use dusty red (base0A) instead: sign, virtual text, float and underline.
  local ep = MiniBase16.config.palette
  vim.api.nvim_set_hl(0, 'DiagnosticError', { fg = ep.base0A })
  vim.api.nvim_set_hl(0, 'DiagnosticFloatingError', { fg = ep.base0A, bg = ep.base01 })
  vim.api.nvim_set_hl(0, 'DiagnosticUnderlineError', { underline = true, sp = ep.base0A })
  -- 0.11 defaults already give K, grn, gra, grr, gri, [d ]d, <C-s>
  vim.keymap.set('n', 'gd', vim.lsp.buf.definition)
  vim.keymap.set('n', '<leader>f', vim.lsp.buf.format)

  add('whonore/Coqtail') -- Coq: <leader>cc start, cj/ck step, cl to cursor
  vim.api.nvim_create_autocmd('FileType', {
    pattern = { 'python', 'c' },
    callback = function() vim.bo.textwidth = 99 end,
  })
  -- Python docstrings read as comments; other strings stay pink. Vim's python syntax has no docstring group, so a
  -- triple-quoted string that starts its line counts as one (assigned / argument strings don't start the line).
  -- Defined after python.vim's pythonString, so it wins where both match.
  vim.api.nvim_create_autocmd('Syntax', { pattern = 'python', callback = function()
    vim.cmd([[syn region pythonDocstring start=+^\s*\zs[rRuU]\=\z('''\|"""\)+ skip=+\\["']+ end=+\z1+ keepend contains=@Spell]])
    vim.cmd('hi def link pythonDocstring Comment')
  end })
end)

-- Explorer (right) + zsh terminal (bottom): VSCode-style layout --------------
now(function()
  add('nvim-tree/nvim-tree.lua')
  require('nvim-tree').setup({
    hijack_directories = { enable = false },
    view = { side = 'right', width = '15%' },
    update_focused_file = { enable = true },
    sync_root_with_cwd = true, -- tree follows :cd
    filters = { dotfiles = false, git_ignored = false }, -- never hide; muted below instead
    renderer = {
      highlight_hidden = 'name',
      highlight_git = 'name', -- colours set below
      -- Root header: drop leading dirs until it fits the tree ('~/a/b/proj' -> '…/b/proj'), not cut off mid-name.
      root_folder_label = function(path)
        local win = require('nvim-tree.api').tree.winid()
        local max = win and vim.api.nvim_win_get_width(win) - vim.fn.getwininfo(win)[1].textoff - 1
          or math.floor(vim.o.columns * 0.15) - 3
        local parts = vim.split(vim.fn.fnamemodify(path, ':~'), '/')
        local label = table.concat(parts, '/')
        while #parts > 1 and vim.fn.strdisplaywidth(label) > max do
          table.remove(parts, 1)
          label = '…/' .. table.concat(parts, '/')
        end
        return label
      end,
    },
  })
  -- Dotfiles and gitignored nodes: comment-grey text on a faint bg.
  local p = MiniBase16.config.palette
  for _, g in ipairs({ 'HiddenFileHL', 'HiddenFolderHL', 'GitFileIgnoredHL', 'GitFolderIgnoredHL' }) do
    vim.api.nvim_set_hl(0, 'NvimTree' .. g, { fg = p.base03, bg = p.base01 })
  end
  -- Git states get Black Metal's three accents (ghostty palette 1-3); icon and name share the colour.
  -- New = base0B like mini.diff's add sign, modified = base0A, staged = base08, conflict = bold base0A.
  -- Deleted / renamed stay plain.
  local git = {
    New = { fg = p.base0B }, Dirty = { fg = p.base0A }, Staged = { fg = p.base08 },
    Merge = { fg = p.base0A, bold = true }, Deleted = {}, Renamed = {},
  }
  for state, hl in pairs(git) do
    vim.api.nvim_set_hl(0, 'NvimTreeGitFile' .. state .. 'HL', hl)
    vim.api.nvim_set_hl(0, 'NvimTreeGitFolder' .. state .. 'HL', hl)
    if next(hl) then vim.api.nvim_set_hl(0, 'NvimTreeGit' .. state .. 'Icon', hl) end
  end
  vim.keymap.set('n', '<leader>e', '<cmd>NvimTreeToggle<cr>')

  -- Terminal sessions share the bottom pane, tmux-style: C-a c new, C-a n/p cycle.
  -- A session list sits bottom-right under the tree (VSCode-style): C-a w focuses it, <CR> switches.
  -- Unlisted so ;l/;h and the tabline only cycle code buffers.
  vim.api.nvim_create_autocmd('TermOpen', { callback = function() vim.bo.buflisted = false end })
  local function is_term(b) -- shell terminals only; the claudecode.nvim pane is a terminal too
    return vim.bo[b].buftype == 'terminal' and not vim.api.nvim_buf_get_name(b):match('//%d+:%S*claude')
  end
  local function terms() return vim.tbl_filter(is_term, vim.api.nvim_list_bufs()) end
  local function find_win(pred)
    return vim.iter(vim.api.nvim_tabpage_list_wins(0)):find(function(w) return pred(vim.api.nvim_win_get_buf(w)) end)
  end
  local list_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[list_buf].filetype = 'termlist'
  local is_list = function(b) return b == list_buf end

  local function list_render()
    local win, tw = find_win(is_list), find_win(is_term)
    local shown = tw and vim.api.nvim_win_get_buf(tw)
    local lines = {}
    for i, b in ipairs(terms()) do
      local name, title = vim.api.nvim_buf_get_name(b), vim.b[b].term_title
      if not title or title == name then title = vim.fn.fnamemodify(name, ':t') end -- 'zsh' until the shell sets a title
      lines[i] = (b == shown and '▶ ' or '  ') .. i .. ' ' .. title
    end
    vim.bo[list_buf].modifiable = true
    vim.api.nvim_buf_set_lines(list_buf, 0, -1, false, lines)
    vim.bo[list_buf].modifiable = false
    if win then vim.api.nvim_win_set_width(win, math.floor(vim.o.columns * 0.15)) end -- match nvim-tree '15%'
  end

  local function term_show(buf) -- focus the bottom pane (recreate if closed), show buf or a new shell
    local win = find_win(is_term)
    if win then
      vim.api.nvim_set_current_win(win)
    else
      local lw = find_win(is_list)
      if lw then vim.api.nvim_win_close(lw, true) end
      vim.cmd('botright split')
      vim.cmd.resize(math.floor(vim.o.lines * 0.2))
      vim.wo.winfixheight = true
    end
    if not find_win(is_list) then
      vim.cmd('rightbelow vsplit')
      vim.api.nvim_win_set_buf(0, list_buf)
      vim.wo.winfixwidth, vim.wo.number, vim.wo.relativenumber, vim.wo.cursorline = true, false, false, true
      vim.wo.signcolumn = 'no'
      vim.cmd.wincmd('p')
    end
    if buf then vim.api.nvim_win_set_buf(0, buf) else vim.cmd.terminal() end
    list_render()
  end
  local function term_cycle(step)
    local t = terms()
    if #t == 0 then return term_show() end
    local i = vim.fn.index(t, vim.api.nvim_get_current_buf()) -- -1 when not in a terminal
    term_show(t[(i + step) % #t + 1])
  end

  local pick = function() local b = terms()[vim.fn.line('.')]; if b then term_show(b) end end
  vim.keymap.set('n', '<CR>', pick, { buffer = list_buf })
  vim.keymap.set('n', '<2-LeftMouse>', pick, { buffer = list_buf })
  vim.api.nvim_create_autocmd({ 'TermOpen', 'TermClose', 'BufWinEnter', 'BufWipeout', 'VimResized' }, {
    callback = function() vim.schedule(list_render) end,
  })

  local tmap = function(lhs, fn) vim.keymap.set({ 'n', 't' }, '<C-a>' .. lhs, fn) end
  tmap('c', function() term_show() end)
  tmap('n', function() term_cycle(1) end)
  tmap('p', function() term_cycle(-1) end)
  tmap('w', function()
    if not find_win(is_list) then term_show(terms()[1]) end -- recreate the bottom pane if closed
    vim.api.nvim_set_current_win(find_win(is_list))
  end)

  -- :Octo opens via :edit in the current window. If that was the terminal / Claude / tree / list pane, move the
  -- octo buffer to the code window (right of Claude; one is split off Claude if none) and put the pane back.
  -- Octo buffers are listed, so ;l/;h, C-n/C-p and ;fb cycle them with files.
  local is_code = function(b) return vim.bo[b].buftype == '' or vim.bo[b].buftype == 'acwrite' end
  local moving = false -- our own win_set_buf / open_win re-fire BufWinEnter
  vim.api.nvim_create_autocmd('BufWinEnter', { pattern = 'octo://*', callback = function(ev)
    local win, prev = vim.api.nvim_get_current_win(), vim.fn.bufnr('#')
    if moving or prev == -1 or is_code(prev) then return end
    vim.schedule(function()
      local code = vim.iter(vim.api.nvim_tabpage_list_wins(0)):find(function(w)
        return w ~= win and vim.api.nvim_win_get_config(w).relative == '' and is_code(vim.api.nvim_win_get_buf(w))
      end)
      local claude = find_win(function(b) return vim.bo[b].buftype == 'terminal' and not is_term(b) end)
      moving = true
      if code then vim.api.nvim_win_set_buf(code, ev.buf)
      else code = vim.api.nvim_open_win(ev.buf, false, claude and { split = 'right', win = claude } or { split = 'left', win = -1 }) end
      vim.api.nvim_win_set_buf(win, prev)
      moving = false
      vim.api.nvim_set_current_win(code)
    end)
  end })

  -- Build (or rebuild, C-a r) the layout: one code window + tree, terminal + session list. Other windows close;
  -- their buffers, shells and Claude's process stay alive (hidden). The Claude pane comes back if it was showing.
  local function layout()
    local claude_shown = find_win(function(b) return vim.bo[b].buftype == 'terminal' and not is_term(b) end) ~= nil
    local code = vim.iter(vim.api.nvim_tabpage_list_wins(0)):find(function(w)
      return vim.api.nvim_win_get_config(w).relative == '' and is_code(vim.api.nvim_win_get_buf(w))
    end)
    if code then vim.api.nvim_set_current_win(code) end
    vim.cmd('only')
    if not is_code(vim.api.nvim_get_current_buf()) then vim.cmd.enew() end
    code = vim.api.nvim_get_current_win()
    require('nvim-tree.api').tree.open()
    term_show(terms()[1]) -- reuse the first shell, or start one
    vim.api.nvim_set_current_win(code)
    if claude_shown then require('claudecode.terminal').ensure_visible() end
  end
  tmap('r', layout)

  vim.api.nvim_create_autocmd('VimEnter', {
    nested = true, -- let TermOpen etc. fire for the startup terminal
    callback = function()
      local arg = vim.fn.argv(0)
      if arg ~= '' and vim.fn.isdirectory(arg) == 1 then
        vim.cmd.cd(arg)
        vim.cmd('enew | bwipeout #')
      end
      layout()
    end,
  })
end)

-- Editing / navigation (later = after startup) -------------------------------
later(function()
  require('mini.surround').setup()   -- vim-surround: sa / sd / sr
  require('mini.trailspace').setup() -- BadWhiteSpace highlight
  require('mini.git').setup()        -- fugitive: :Git
  -- Octicons (nf-oct-diff_added / diff_modified / diff_removed) left of the line numbers. Same icons for staged
  -- lines below, in teal; unstaged ones use the tree's colours: new = pink, modified / removed = dusty red.
  local diff_icons = { add = '\u{f457}', change = '\u{f459}', delete = '\u{f458}' }
  require('mini.diff').setup({ view = { style = 'sign', signs = diff_icons } })
  local dp = MiniBase16.config.palette
  vim.api.nvim_set_hl(0, 'MiniDiffSignAdd', { fg = dp.base0B, bg = dp.base01 })
  vim.api.nvim_set_hl(0, 'MiniDiffSignChange', { fg = dp.base0A, bg = dp.base01 })
  vim.api.nvim_set_hl(0, 'MiniDiffSignDelete', { fg = dp.base0A, bg = dp.base01 })
  -- Staged lines. mini.diff diffs against the index, so a staged hunk simply disappears from it (and with
  -- 'number' set it colours line numbers, leaving the sign column free). Mark staged lines there in the tree's
  -- staged teal, from `git diff --cached`. Those line numbers are index lines; mini.diff's hunks (index vs
  -- buffer) shift them onto buffer lines. Recomputed on every MiniDiffUpdated: text edits and index changes.
  local staged_ns = vim.api.nvim_create_namespace('staged_signs')
  vim.api.nvim_set_hl(0, 'StagedSign', { fg = dp.base08, bg = dp.base01 })
  local function index_to_buf_line(l, hunks)
    local shift = 0
    for _, h in ipairs(hunks) do
      local ref_last = h.ref_start + h.ref_count - 1
      if h.ref_count > 0 and l >= h.ref_start and l <= ref_last then return h.buf_start end -- edited again since staging
      if (h.ref_count == 0 and h.ref_start < l) or (h.ref_count > 0 and ref_last < l) then
        shift = shift + h.buf_count - h.ref_count
      end
    end
    return l + shift
  end
  local function staged_signs(buf)
    local data, file = MiniDiff.get_buf_data(buf), vim.api.nvim_buf_get_name(buf)
    if not data or file == '' then return end
    local cmd = { 'git', 'diff', '--cached', '-U0', '--no-color', '--', file }
    vim.system(cmd, { cwd = vim.fs.dirname(file), text = true }, vim.schedule_wrap(function(out)
      if not vim.api.nvim_buf_is_valid(buf) then return end
      vim.api.nvim_buf_clear_namespace(buf, staged_ns, 0, -1)
      local last = vim.api.nvim_buf_line_count(buf)
      for old_count, start, count in (out.stdout or ''):gmatch('\n@@ %-%d+,?(%d*) %+(%d+),?(%d*) @@') do
        old_count, start, count = tonumber(old_count) or 1, tonumber(start), tonumber(count) or 1
        local icon = count == 0 and diff_icons.delete or old_count == 0 and diff_icons.add or diff_icons.change
        for l = start, start + math.max(count, 1) - 1 do -- count 0: staged deletion, marked where it was
          local row = math.min(math.max(index_to_buf_line(l, data.hunks), 1), last) - 1
          -- priority below mini.diff's 199: a line edited again since staging shows its unstaged icon
          vim.api.nvim_buf_set_extmark(buf, staged_ns, row, 0, { sign_text = icon, sign_hl_group = 'StagedSign', priority = 150 })
        end
      end
    end))
  end
  vim.api.nvim_create_autocmd('User', {
    pattern = 'MiniDiffUpdated',
    callback = function() staged_signs(vim.api.nvim_get_current_buf()) end,
  })
  -- every picker (incl. vim.ui.select): float centered over the code window (widest file window, so not
  -- Claude / tree / terminal), 80% of its width, 20 result rows (prompt sits in the top border)
  local function code_win()
    return vim.iter(vim.api.nvim_tabpage_list_wins(0)):filter(function(w)
      local bt = vim.bo[vim.api.nvim_win_get_buf(w)].buftype
      return vim.api.nvim_win_get_config(w).relative == '' and (bt == '' or bt == 'acwrite')
    end):fold(nil, function(best, w)
      return (not best or vim.api.nvim_win_get_width(w) > vim.api.nvim_win_get_width(best)) and w or best
    end)
  end
  local centered = { config = function()
    local code = code_win()
    local r, c, W, H = 0, 0, vim.o.columns, vim.o.lines - 2 -- no code window: whole editor
    if code then
      r, c = unpack(vim.api.nvim_win_get_position(code))
      W, H = vim.api.nvim_win_get_width(code), vim.api.nvim_win_get_height(code)
    end
    local w, h = math.floor(W * 0.8), math.max(1, math.min(20, H - 2))
    return { anchor = 'NW', width = w, height = h, row = r + math.floor((H - h - 2) / 2), col = c + math.floor((W - w - 2) / 2) }
  end }
  require('mini.pick').setup({ window = centered }) -- command-t / fzf
  local map = vim.keymap.set
  map('n', '<leader>ff', '<cmd>Pick files<cr>')
  map('n', '<leader>fg', '<cmd>Pick grep_live<cr>')
  map('n', '<leader>fb', '<cmd>Pick buffers<cr>')
  map('n', '<leader>fh', '<cmd>Pick help<cr>')


  -- C-a d / D: fuzzy-pick a directory under . / ~ and :cd into it (.git, caches, node_modules, ~/Library, ~/go/pkg skipped)
  -- Dirs come from rg's file list (parallel, honours .gitignore): ~3s over ~ vs ~14s for /usr/bin/find. Empty dirs don't show.
  local function pick_cd(root)
    root = vim.fn.expand(root)
    MiniPick.builtin.cli({ command = { 'sh', '-c', "rg --files --hidden -g '!.git' -g '!node_modules' -g '!.cache' -g '!.npm'"
      .. " -g '!.Trash' -g '!/Library' -g '!/go/pkg' 2>/dev/null"
      .. [[ | awk -F/ '{ p = ""; for (i = 1; i < NF; i++) { p = p (i > 1 ? "/" : "") $i; if (!seen[p]++) print p } }']] } },
      { source = { name = 'cd ' .. root, cwd = root, choose = function(d) vim.cmd.cd(vim.fs.joinpath(root, d)) end } })
  end
  -- C-a f / F: live search of file names AND file contents under . / ~ (rg, smart-case, plain text)
  -- ponytail: reruns rg on every keystroke; ~ can lag, add a debounce if it does
  local function pick_grep(root)
    root = vim.fn.expand(root)
    -- from a terminal / Claude pane, start in the code window so the chosen file opens there, not over the terminal
    if vim.bo.buftype == 'terminal' and code_win() then vim.api.nvim_set_current_win(code_win()) end
    local sys = { kill = function() end }
    MiniPick.start({ source = { name = 'Files + grep ' .. root, cwd = root, items = {},
      match = function(_, _, query)
        sys.kill()
        if #query == 0 then return MiniPick.set_picker_items({}, { do_match = false }) end
        sys = MiniPick.set_picker_items_from_cli({ 'sh', '-c',
          'rg --files | rg -S -F -- "$1"; rg -S -F -n --column --no-heading --color=never -M 200 --field-match-separator "\\x00" -- "$1"',
          '_', table.concat(query) }, { set_items_opts = { do_match = false }, spawn_opts = { cwd = root } })
      end,
      show = function(buf, items, query) MiniPick.default_show(buf, items, query, { show_icons = true }) end,
    } })
  end
  map({ 'n', 't' }, '<C-a>d', function() pick_cd('.') end)
  map({ 'n', 't' }, '<C-a>D', function() pick_cd('~') end)
  map({ 'n', 't' }, '<C-a>f', function() pick_grep('.') end)
  map({ 'n', 't' }, '<C-a>F', function() pick_grep('~') end)

  -- Diff review: diffview for local/range diffs, octo for GitHub PR reviews (via gh)
  add('sindrets/diffview.nvim')
  add({ source = 'pwntester/octo.nvim', depends = { 'nvim-lua/plenary.nvim' } })
  require('octo').setup({ picker = 'default' }) -- built-in vim.ui.select menu
  -- Octo bug workarounds: the cached bubble end-cap groups (octo_mf_<hex> fg, octo_mb_<hex> bg) aren't rebuilt after
  -- a colorscheme reload (ends turn Normal-grey), and the Destroyed bubble asks for OctoBubbleGray (defined as Grey).
  local function octo_hl_fix()
    vim.api.nvim_set_hl(0, 'OctoBubbleGray', { link = 'OctoBubbleGrey', default = true })
    for g in vim.fn.execute('highlight'):gmatch('\n(octo_m[fb]_%x+)') do -- :hi still lists cleared groups; getcompletion doesn't
      local mode, hex = g:match('^octo_m([fb])_(%x%x%x%x%x%x)$')
      if mode == 'f' then vim.api.nvim_set_hl(0, g, { fg = '#' .. hex }) end
      if mode == 'b' then -- same black/white text choice octo makes
        local r, gr, b = tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
        vim.api.nvim_set_hl(0, g, { bg = '#' .. hex, fg = (0.299 * r + 0.587 * gr + 0.114 * b) / 255 > 0.5 and '#000000' or '#ffffff' })
      end
    end
  end
  octo_hl_fix()
  vim.api.nvim_create_autocmd('ColorScheme', { callback = octo_hl_fix })
  -- Rendered markdown (headings, bullets, code blocks, tables) in octo and .md buffers; raw text on the cursor line.
  -- html.tag hides the listed tags (keeping their text); <a> gets a link icon + link highlight. <details> is octo's (folds).
  add('MeanderingProgrammer/render-markdown.nvim')
  require('render-markdown').setup({
    file_types = { 'markdown', 'octo' },
    html = { tag = {
      a = { icon = '󰌹 ', highlight = 'RenderMarkdownLink', scope_highlight = 'RenderMarkdownLink' },
      p = {}, summary = {}, b = {}, strong = {}, em = {}, sub = {}, sup = {}, code = {},
    } },
  })
  -- Diffview gets its own tab (it's tab-based); mirror the Claude pane on its left so it reads Claude | diff.
  -- DiffviewClose drops the tab, leaving the main layout untouched. No-op when Claude isn't running.
  require('diffview').setup({ hooks = { view_opened = function()
    local claude = require('claudecode.terminal').get_active_terminal_bufnr()
    if not claude then return end
    vim.cmd('topleft ' .. math.floor(vim.o.columns * 0.30) .. 'vsplit') -- matches split_width_percentage
    vim.api.nvim_win_set_buf(0, claude)
    vim.wo.winfixwidth = true
    vim.cmd.wincmd('p')
  end } })
  map('n', '<leader>gd', '<cmd>DiffviewOpen<cr>')
  map('n', '<leader>gc', '<cmd>DiffviewClose<cr>')
  -- Resolve conflicts in the normal buffer: co / ct / cb (both) / c0 (none), ]x / [x, :GitConflictListQf.
  -- Its default colours come from DiffText/DiffAdd bg, which are both base01 here, so ours and theirs looked the
  -- same. Use dark tints of the tree's git colours instead: ours = teal (staged), theirs = pink (new).
  -- The plugin derives the lighter label-row colours from these.
  add('akinsho/git-conflict.nvim')
  local function tint(hex, a) -- hex mixed into black: a = 0 black, 1 unchanged
    local n = tonumber(hex:sub(2), 16)
    local r, g, b = math.floor(n / 65536), math.floor(n / 256) % 256, n % 256
    return string.format('#%02x%02x%02x', math.floor(r * a), math.floor(g * a), math.floor(b * a))
  end
  local bp = MiniBase16.config.palette
  vim.api.nvim_set_hl(0, 'ConflictOurs', { bg = tint(bp.base08, 0.45) })
  vim.api.nvim_set_hl(0, 'ConflictTheirs', { bg = tint(bp.base0B, 0.35) })
  -- Its buffer-local maps (and disable_diagnostics) target whichever buffer is current when a redraw detects the
  -- conflict, usually the tree or terminal here, so they're off. Same keys mapped globally instead: they act only
  -- when git reports this file as conflicted, else fall through to native ct{char} / cb / c0 (an rhs starting
  -- with its lhs isn't remapped, :h recursive_mapping). Asking the plugin, not searching for <<<<<<<, keeps
  -- marker-like text in ordinary files (fixtures, docs) from hijacking the keys. pcall: conflict_count errors on
  -- a conflicted file whose buffer it hasn't drawn yet.
  local gc = require('git-conflict')
  gc.setup({
    default_mappings = false,
    highlights = { current = 'ConflictOurs', incoming = 'ConflictTheirs' },
  })
  local conflict_keys = { co = 'ours', ct = 'theirs', cb = 'both', c0 = 'none', [']x'] = 'next-conflict', ['[x'] = 'prev-conflict' }
  for lhs, action in pairs(conflict_keys) do
    map('n', lhs, function()
      local ok, n = pcall(gc.conflict_count, 0)
      return ok and n > 0 and '<Plug>(git-conflict-' .. action .. ')' or lhs
    end, { expr = true, remap = true, desc = 'git-conflict: ' .. action })
  end
  -- It scans on VimEnter / BufRead, which have already fired by the time later() runs, so files opened at
  -- startup were missed. Replay just its own handler once (also starts its .git watcher).
  vim.api.nvim_exec_autocmds('BufRead', { group = 'GitConflictCommands' })
  -- diffview only refreshes on in-nvim saves / index changes; catch external edits too
  vim.api.nvim_create_autocmd({ 'FocusGained', 'TabEnter' }, {
    callback = function()
      vim.cmd('silent! checktime')
      if require('diffview.lib').get_current_view() then vim.cmd('DiffviewRefresh') end
    end,
  })
  map('n', '<leader>gp', function() -- current branch's PR vs its base (after `gh pr checkout N`)
    local base = vim.trim(vim.fn.system({ 'gh', 'pr', 'view', '--json', 'baseRefName', '-q', '.baseRefName' }))
    if vim.v.shell_error ~= 0 then return vim.notify('No PR for this branch', vim.log.levels.WARN) end
    vim.cmd('DiffviewOpen origin/' .. base .. '...HEAD')
  end)
  map('n', '<leader>or', '<cmd>Octo review start<cr>')

  -- What changed (e.g. Claude's edits): hunk picker with preview, <CR> jumps to file:line; <C-a> + <M-CR> -> quickfix
  require('mini.extra').setup()
  map('n', '<leader>gh', '<cmd>Pick git_hunks<cr>')
  map('n', '<leader>gH', "<cmd>Pick git_hunks scope='staged'<cr>")
  map('n', '<leader>gm', function() -- new + modified files
    MiniPick.builtin.cli({ command = { 'git', 'ls-files', '--modified', '--others', '--exclude-standard', '--deduplicate' } },
      { source = { name = 'Changed files' } })
  end)
  map('n', '<leader>go', function() MiniDiff.toggle_overlay() end) -- old vs new inline; ]h / [h between hunks
  -- Claude writes from nvim's own terminal, so FocusGained never fires; reload buffers on moving between windows
  vim.api.nvim_create_autocmd({ 'BufEnter', 'WinEnter', 'TermLeave' }, { command = 'silent! checktime' })
  -- ...and also as soon as anything under cwd changes on disk, without waiting for a window hop. Recursive
  -- fs_event works on macOS/Windows (Linux would need one watcher per directory). Debounced, since agents and git
  -- touch many files at once; .git is skipped (git-conflict watches it). Re-armed when the tree follows a :cd.
  local cwd_watcher, reload_timer = vim.uv.new_fs_event(), vim.uv.new_timer()
  local function watch_cwd()
    cwd_watcher:stop()
    cwd_watcher:start(vim.fn.getcwd(), { recursive = true }, function(err, name)
      if err or (name and name:match('^%.git/')) then return end
      reload_timer:stop()
      reload_timer:start(150, 0, vim.schedule_wrap(function() vim.cmd('silent! checktime') end))
    end)
  end
  watch_cwd()
  vim.api.nvim_create_autocmd('DirChanged', { callback = watch_cwd })
  vim.api.nvim_create_autocmd('VimLeavePre', { callback = function() cwd_watcher:stop(); reload_timer:close() end })

  -- Claude Code in a left-side pane (native terminal; connects to the claude CLI via its IDE protocol)
  add('coder/claudecode.nvim')
  require('claudecode').setup({ terminal = { split_side = 'left', split_width_percentage = 0.30 } })
  map({ 'n', 't' }, '<C-a>P', '<cmd>ClaudeCode<cr>')          -- new session (or show/hide the running one)
  map({ 'n', 't' }, '<C-a>R', '<cmd>ClaudeCode --resume<cr>') -- same, but a fresh launch opens claude's session list
  map('v', '<leader>as', '<cmd>ClaudeCodeSend<cr>') -- send selection to Claude
end)
