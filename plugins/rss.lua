-- rss.lua — NEURODECK Plugin
-- Fetch and browse RSS/Atom feeds in the terminal
-- Commands: /rss /addfeed /feeds /delfeed

local state_file = (os.getenv("HOME") or os.getenv("USERPROFILE") or ".") .. "/.config/neurodeck/data/rss_feeds.txt"

local DEFAULT_FEEDS = {
    { name = "Hacker News", url = "https://news.ycombinator.com/rss" },
    { name = "LWN.net",     url = "https://lwn.net/headlines/rss" },
}

local function load_feeds()
    local feeds = {}
    local f = io.open(state_file, "r")
    if f then
        for line in f:lines() do
            local name, url = line:match("^(.-)%|(.+)$")
            if name and url then table.insert(feeds, { name = name, url = url }) end
        end
        f:close()
    end
    if #feeds == 0 then feeds = DEFAULT_FEEDS end
    return feeds
end

local function save_feeds(feeds)
    local f = io.open(state_file, "w")
    if not f then return end
    for _, feed in ipairs(feeds) do
        f:write(feed.name .. "|" .. feed.url .. "\n")
    end
    f:close()
end

local function fetch_feed(url, limit)
    limit = limit or 5
    local r = io.popen("curl -s --max-time 10 --compressed '" .. url:gsub("'", "") .. "' 2>/dev/null")
    if not r then print("[RSS] curl not available.") return end
    local xml = r:read("*a"); r:close()
    if not xml or xml == "" then print("[RSS] Failed to fetch: " .. url) return end

    local items = {}
    -- Parse <item> or <entry> blocks
    for block in xml:gmatch("<item>(.-)</item>") do
        local title = block:match("<title><!%[CDATA%[(.-)%]%]></title>") or block:match("<title>(.-)</title>") or "Untitled"
        local link  = block:match("<link>(.-)</link>") or block:match('<link href="(.-)"') or ""
        title = title:gsub("&amp;", "&"):gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&quot;", '"')
        table.insert(items, { title = title:sub(1,80), link = link })
        if #items >= limit then break end
    end
    -- Atom fallback
    if #items == 0 then
        for block in xml:gmatch("<entry>(.-)</entry>") do
            local title = block:match("<title>(.-)</title>") or "Untitled"
            local link  = block:match('<link href="(.-)"') or ""
            table.insert(items, { title = title:sub(1,80), link = link })
            if #items >= limit then break end
        end
    end

    if #items == 0 then
        print("[RSS] No items found. Feed may use an unsupported format.")
        return
    end
    for i, item in ipairs(items) do
        print(string.format("[%d] %s", i, item.title))
        if item.link ~= "" then print("    " .. item.link) end
    end
end

registerCommand("rss", function(args)
    local feeds = load_feeds()
    local n = tonumber(args)
    if n and feeds[n] then
        print("[RSS] Fetching: " .. feeds[n].name)
        fetch_feed(feeds[n].url)
    elseif args and args:match("^https?://") then
        print("[RSS] Fetching: " .. args)
        fetch_feed(args)
    else
        print("[RSS] Saved feeds (use /rss <n> to read):")
        for i, feed in ipairs(feeds) do
            print(string.format("  [%d] %s — %s", i, feed.name, feed.url))
        end
    end
end)

registerCommand("addfeed", function(args)
    if not args then print("Usage: /addfeed <Name> <URL>") return end
    local name, url = args:match("^(.-)%s+(https?://.+)$")
    if not name then print("Usage: /addfeed My Blog https://example.com/rss") return end
    local feeds = load_feeds()
    table.insert(feeds, { name = name, url = url })
    save_feeds(feeds)
    print("[RSS] Added: " .. name)
end)

registerCommand("delfeed", function(args)
    local n = tonumber(args)
    if not n then print("Usage: /delfeed <n>") return end
    local feeds = load_feeds()
    if not feeds[n] then print("[RSS] No feed #" .. n) return end
    print("[RSS] Removed: " .. feeds[n].name)
    table.remove(feeds, n)
    save_feeds(feeds)
end)

registerCommand("feeds", function()
    local feeds = load_feeds()
    for i, f in ipairs(feeds) do
        print(string.format("[%d] %s — %s", i, f.name, f.url))
    end
end)

print("[Plugin] RSS Reader loaded. Commands: /rss /addfeed /feeds /delfeed")
