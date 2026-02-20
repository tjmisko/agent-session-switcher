-- agent-sessions/init.lua — Neovim integration for agent-session-switcher
-- Add to rtp: vim.opt.rtp:prepend(vim.fn.expand("~/Projects/agent-session-switcher"))

local M = {}

local bin_dir = vim.fn.expand("~/Projects/agent-session-switcher/bin")

local function open_floating_terminal(cmd)
    local buf = vim.api.nvim_create_buf(false, true)
    local width = math.floor(vim.o.columns * 0.8)
    local height = math.floor(vim.o.lines * 0.8)
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        style = "minimal",
        border = "rounded",
    })

    vim.fn.termopen(cmd, {
        on_exit = function()
            if vim.api.nvim_win_is_valid(win) then
                vim.api.nvim_win_close(win, true)
            end
        end,
    })

    vim.cmd("startinsert")
end

local function get_active_session()
    local state_dir = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/agent-session-switcher"
    local f = io.open(state_dir .. "/active-session", "r")
    if not f then
        return nil
    end
    local name = f:read("*l")
    f:close()
    return name
end

local function send_to_session(text)
    local session = get_active_session()
    if not session then
        vim.notify("No active agent session", vim.log.levels.WARN)
        return
    end

    -- Send text to tmux session via send-keys
    vim.fn.system({ "tmux", "send-keys", "-t", session, text, "Enter" })
    vim.notify("Sent to " .. session, vim.log.levels.INFO)
end

local function gather_context()
    local parts = {}

    -- Current buffer file
    local current = vim.fn.expand("%:p")
    if current ~= "" then
        table.insert(parts, "Current file: " .. current)
    end

    -- All listed buffers
    local bufs = {}
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buflisted then
            local name = vim.api.nvim_buf_get_name(buf)
            if name ~= "" then
                table.insert(bufs, name)
            end
        end
    end
    if #bufs > 0 then
        table.insert(parts, "Open buffers: " .. table.concat(bufs, ", "))
    end

    -- Quickfix list
    local qf = vim.fn.getqflist()
    if #qf > 0 then
        local qf_items = {}
        for _, item in ipairs(qf) do
            local fname = vim.fn.bufname(item.bufnr)
            table.insert(qf_items, fname .. ":" .. item.lnum .. ": " .. item.text)
        end
        table.insert(parts, "Quickfix:\n" .. table.concat(qf_items, "\n"))
    end

    -- Harpoon marks (if available)
    local ok, harpoon = pcall(require, "harpoon")
    if ok then
        local list = harpoon:list()
        if list and list.items then
            local marks = {}
            for _, item in ipairs(list.items) do
                table.insert(marks, item.value)
            end
            if #marks > 0 then
                table.insert(parts, "Harpoon marks: " .. table.concat(marks, ", "))
            end
        end
    end

    return table.concat(parts, "\n\n")
end

function M.open_picker()
    open_floating_terminal(bin_dir .. "/agent-session-picker")
end

function M.send_context()
    local ctx = gather_context()
    send_to_session("Context from nvim:\n" .. ctx)
end

function M.setup(opts)
    opts = opts or {}

    vim.keymap.set("n", "<A-a>", M.open_picker, { desc = "Agent session picker" })
    vim.keymap.set("n", "<A-f>", M.open_picker, { desc = "Agent session picker" })
    vim.keymap.set("n", "<A-c>", M.send_context, { desc = "Send context to agent" })
end

return M
