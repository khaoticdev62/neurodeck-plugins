-- dbtools.lua — NEURODECK Plugin
-- Quick SQLite, PostgreSQL (psql), and MySQL database shortcuts
-- Commands: /sqlite /psql /mysql /dbschema /dbtables /dbexport

local function is_windows()
    return (os.getenv("OS") or ""):find("Windows") ~= nil
end

local function which(bin)
    local cmd = is_windows() and ("where " .. bin .. " 2>nul") or ("which " .. bin .. " 2>/dev/null")
    local r = io.popen(cmd)
    if not r then return nil end
    local path = r:read("*l"); r:close()
    return (path and path ~= "") and path or nil
end

-- ── SQLite ────────────────────────────────────────────────────────────────────

local sqlite_db = nil

registerCommand("sqlite", function(args)
    if not which("sqlite3") then
        print("[DB] sqlite3 not found. Install with: sudo pacman -S sqlite  or  sudo apt install sqlite3")
        return
    end
    if not args or args == "" then
        if not sqlite_db then
            print("Usage: /sqlite <path-to-db.sqlite>  — connect to a database")
            print("       /sqlite :memory:              — open an in-memory DB")
            return
        end
        print("[SQLite] Connected to: " .. sqlite_db)
        return
    end
    -- If it looks like a file path, connect. Otherwise run a query.
    if args:match("%.sqlite$") or args:match("%.db$") or args == ":memory:" then
        sqlite_db = args
        print("[SQLite] Connected: " .. args)
    else
        if not sqlite_db then print("[SQLite] Connect first: /sqlite <file.db>") return end
        local escaped = args:gsub("'", "''")
        execute("sqlite3 '" .. sqlite_db .. "' '" .. escaped .. "'")
    end
end)

registerCommand("dbtables", function(args)
    local db = args or sqlite_db
    if not db then print("Usage: /dbtables <db-file>  or connect with /sqlite first") return end
    if not which("sqlite3") then print("[DB] sqlite3 not found.") return end
    execute("sqlite3 '" .. db .. "' '.tables'")
end)

registerCommand("dbschema", function(args)
    if not args then print("Usage: /dbschema <table-name>") return end
    if not sqlite_db then print("[SQLite] Connect first: /sqlite <file.db>") return end
    if not which("sqlite3") then print("[DB] sqlite3 not found.") return end
    execute("sqlite3 '" .. sqlite_db .. "' '.schema " .. args .. "'")
end)

registerCommand("dbexport", function(args)
    local db = args or sqlite_db
    if not db then print("Usage: /dbexport <db-file>") return end
    if not which("sqlite3") then print("[DB] sqlite3 not found.") return end
    local out = db:gsub("%.%w+$", "") .. "_export_" .. os.date("%Y%m%d") .. ".sql"
    execute("sqlite3 '" .. db .. "' '.dump' > '" .. out .. "'")
    print("[DB] Exported to: " .. out)
end)

-- ── PostgreSQL ────────────────────────────────────────────────────────────────

registerCommand("psql", function(args)
    if not which("psql") then
        print("[DB] psql not found. Install PostgreSQL client: sudo apt install postgresql-client")
        return
    end
    if not args or args == "" then
        print("Usage: /psql <sql-query>")
        print("       /psql \\dt                   — list tables")
        print("       /psql SELECT * FROM users LIMIT 5")
        print("Set PGHOST/PGUSER/PGPASSWORD/PGDATABASE env vars or use DATABASE_URL.")
        return
    end
    local db_url = os.getenv("DATABASE_URL") or ""
    if db_url ~= "" then
        execute("psql '" .. db_url .. "' -c '" .. args:gsub("'","''") .. "'")
    else
        execute("psql -c '" .. args:gsub("'","''") .. "'")
    end
end)

-- ── MySQL / MariaDB ───────────────────────────────────────────────────────────

registerCommand("mysql", function(args)
    if not which("mysql") then
        print("[DB] mysql client not found. Install: sudo apt install mysql-client")
        return
    end
    if not args or args == "" then
        print("Usage: /mysql <sql-query>")
        print("Set MYSQL_HOST/MYSQL_USER/MYSQL_PWD/MYSQL_DATABASE env vars first.")
        return
    end
    local host = os.getenv("MYSQL_HOST") or "localhost"
    local user = os.getenv("MYSQL_USER") or "root"
    local db   = os.getenv("MYSQL_DATABASE") or ""
    local db_arg = db ~= "" and (" -D " .. db) or ""
    execute(string.format("mysql -h %s -u %s%s -e '%s'", host, user, db_arg, args:gsub("'","'\\''") ))
end)

print("[Plugin] DB Tools loaded. Commands: /sqlite /dbtables /dbschema /dbexport /psql /mysql")
