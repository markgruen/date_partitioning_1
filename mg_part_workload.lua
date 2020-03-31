-- print(_VERSION)
-- print(package.path)
--[[
add options for small range lookups. The idea is these lookups will span at most 1 partition
option for a percent of long range and small range lookups
option for index or single row lookups
range_size=N

test end-date setting

--]]

if sysbench.cmdline.command == nil then
   error("Command is required. Supported commands: run")
end

sysbench.cmdline.options = {
    skip_trx = {"Do not use BEGIN/COMMIT; Use global auto_commit value", false},
    start_date = {"start of random date range", "2019-01-01 00:00:00"},
    end_date = {"end of random date range", "2020-01-01 00:00:00"},
    read_pct = {"percentage of read events", 60},
    select_range = {"number of days in select range", 14},
    point_select_id = {"point select by id percent 0-100", 0},
    point_select_date = {"point select by date, percent 0-100", 0},
    point_update_id = {"point update by id, percent 0-100", 30}
}

local pl = require 'pl.import_into'()
local date = require "date"

local START = date(sysbench.cmdline.options.start_date[2])
local END = date(sysbench.cmdline.options.end_date[2])
local d = date.diff(sysbench.cmdline.options.end_date[2],  sysbench.cmdline.options.start_date[2])
local SECRANGE = math.abs(d:spanseconds())

--print(string.format('TOP start: %s d; %s secrange" %s', START, d, SECRANGE))


function readonlytable(table)
   return setmetatable({}, {
     __index = table,
     __newindex = function(table, key, value)
                    error("Attempt to modify read-only table")
                  end,
     __metatable = false
   });
end

function readonly(table)
    local meta = { } -- metatable for proxy
    local proxy = { } -- this table is always empty

    meta.__index = table -- refer to table for lookups
    meta.__newindex = function(t, key, value)
        error("You cannot make any changes to this table!")
    end

    local function iter()
        return next, table
    end

    setmetatable(proxy, meta)
    return proxy, iter -- user will use proxy instead
end

DATA = {start=START, d=d, secrange=SECRANGE}

local regions = { "North East", "South East", "Midwest", "North West", "South West" }


function print_table(node)
    local cache, stack, output = {},{},{}
    local depth = 1
    local output_str = "{\n"

    while true do
        local size = 0
        for k,v in pairs(node) do
            size = size + 1
        end

        local cur_index = 1
        for k,v in pairs(node) do
            if (cache[node] == nil) or (cur_index >= cache[node]) then

                if (string.find(output_str,"}",output_str:len())) then
                    output_str = output_str .. ",\n"
                elseif not (string.find(output_str,"\n",output_str:len())) then
                    output_str = output_str .. "\n"
                end

                -- This is necessary for working with HUGE tables otherwise we run out of memory using concat on huge strings
                table.insert(output,output_str)
                output_str = ""

                local key
                if (type(k) == "number" or type(k) == "boolean") then
                    key = "["..tostring(k).."]"
                else
                    key = "['"..tostring(k).."']"
                end

                if (type(v) == "number" or type(v) == "boolean") then
                    output_str = output_str .. string.rep('\t',depth) .. key .. " = "..tostring(v)
                elseif (type(v) == "table") then
                    output_str = output_str .. string.rep('\t',depth) .. key .. " = {\n"
                    table.insert(stack,node)
                    table.insert(stack,v)
                    cache[node] = cur_index+1
                    break
                else
                    output_str = output_str .. string.rep('\t',depth) .. key .. " = '"..tostring(v).."'"
                end

                if (cur_index == size) then
                    output_str = output_str .. "\n" .. string.rep('\t',depth-1) .. "}"
                else
                    output_str = output_str .. ","
                end
            else
                -- close the table
                if (cur_index == size) then
                    output_str = output_str .. "\n" .. string.rep('\t',depth-1) .. "}"
                end
            end

            cur_index = cur_index + 1
        end

        if (size == 0) then
            output_str = output_str .. "\n" .. string.rep('\t',depth-1) .. "}"
        end

        if (#stack > 0) then
            node = stack[#stack]
            stack[#stack] = nil
            depth = cache[node] == nil and depth + 1 or depth - 1
        else
            break
        end
    end
    -- This is necessary for working with HUGE tables otherwise we run out of memory using concat on huge strings
    table.insert(output,output_str)
    output_str = table.concat(output)

    print(output_str)
end

--[[print(string.format('BEFORE readonly'))
print_table(DATA)
DATA = readonlytable(DATA)
print(string.format('AFTER readonly'))
print_table(DATA)
--]]

-- d1
local select_counts1 = {
    "select count(*) from big where add_date > %s",
    "select count(*) from big where add_date < %s"
}

-- region d1
local select_counts2 = {
    "select count(*) from big where region='%s' and add_date > %s",
    "select count(*) from big where region='%s' and add_date < %s"

}

-- region d1 d2
local select_counts3 = {
    "select count(*) from big where region='%s' and add_date between '%s' and '%s'"
}

-- d1 d2
local select_counts4 = {
    "select count(*) from big where add_date between '%s' and '%s'"
}



local inserts = {
    "insert into big (region, i, add_date) values ('%s', %d, '%s')"
    }

local updates = {
    "update big set i=if(i is null, 1, i+1) where id=%d"
    }


function _deepcopy(o, tables)
 
  if type(o) ~= 'table' then
    return o
  end
 
  if tables[o] ~= nil then
    return tables[o]
  end
 
  local new_o = {}
  tables[o] = new_o
 
  for k, v in next, o, nil do
    local new_k = _deepcopy(k, tables)
    local new_v = _deepcopy(v, tables)
    new_o[new_k] = new_v
  end
 
  return new_o
end
 
function deepcopy(o)
  return _deepcopy(o, {})
end

function generate_random_date_days(start, days)
    start = date(start)
    --print(string.format('In days start: %s %s days: %d', start, type(start), days))
    local rd1 = start:addseconds(sysbench.rand.uniform(1,days*3600*24))
    if rd1 > END then
        rd1 = END
    end
    return rd1:fmt('%Y-%m-%d %H:%M:%S')
end

function generate_random_date(s)
    local start = date(sysbench.cmdline.options.start_date[2])
    local rd1 = start:addseconds(sysbench.rand.uniform(1,s))
    return rd1:fmt('%Y-%m-%d %H:%M:%S')
end

function generate_random_date_pair(START, S, days)
    local rd1 = generate_random_date(S)
    local rd2 = generate_random_date_days(rd1, 14)
    --print(string.format('rd1 %s rd2: %s', rd1, rd2))
    return rd1, rd2
end


function execute_selects(START, SECRANGE)
    
    local region
    local d1, d2
    local days = sysbench.cmdline.options.select_range

    for i, sql in ipairs(select_counts3) do
        --print(string.format("before dates start: %s s: %s type: %s", START, SECRANGE ,type(SECRANGE)))
        d1, d2 = generate_random_date_pair(START, SECRANGE, days)
        --print(string.format("after dates start: %s s: %s type: %s d1: %s d2: %s", start, SECRANGE ,type(SECRANGE), d1, d2))
        --print(string.format('In for loop: start %s s: %s %s', START, SECRANGE, type(SECRANGE)))
        region = regions[math.random(#regions)]
        --print(string.format('d1: %s d2: %s', d1, d2))
        --con:query(string.format(sql, region, d1, d2))
        db_query(string.format(sql, region, d1, d2))
    end

end


function execute_point_id_select()
    db_query("select count(*) from big where id=".. sb_rand(1, max_id))
end


function execute_point_id_update()
    --print(max_id)
    db_query("update big set i=" .. sb_rand(1, 300000) .. " where id=" ..  sb_rand(1, max_id))
end


function execute_inserts(START, SECRANGE)
    --local region = regions[math.random(#regions)] 
    local region = regions[sysbench.rand.uniform(1,#regions)] 
    --print(string.format('START: %s S: %di region: %s', START, SECRANGE, region))
    local d1 = generate_random_date(SECRANGE) 
    con:query(string.format(inserts[1], region, sysbench.rand.uniform(1000,1000000)*-1, d1))
end

function execute_updates()
    con:query(string.format(updates[1], sysbench.rand.special(2, 10000000)))
end

local function get_max_id()
    sql = "select max(id) from big"
    rs = con:query("select max(id) from big")
    --print(rs.nrows[0])
    row = rs:fetch_row()
    return tonumber(row[1])
end

-- Called by sysbench to initialize script
function thread_init()

    -- globals for script
    drv = sysbench.sql.driver()
    con = drv:connect()
    max_id = get_max_id()
end


-- Called by sysbench when tests are done
function thread_done()

    con:disconnect()
end



-- Called by sysbench for each execution
function event()

    --print(sysbench.opt.end_date)
    if not sysbench.opt.skip_trx then
        con:query("BEGIN")
        --print('begin')
    end

    local SECRANGE = DATA.secrange
    local START = date(sysbench.cmdline.options.start_date[2])
    local read_pct = sysbench.opt.read_pct
    local point_select_pct = sysbench.opt.point_select_id
    local point_update_pct = sysbench.opt.point_update_id
    local k = sysbench.rand.uniform(1,100)
    local l = sysbench.rand.uniform(1,100)
    local m = sysbench.rand.uniform(1,100)

    --print(string.format('event start: %s opt: %s', START, sysbench.opt.start_date))
    --print(string.format('event SECRANGE: %s', SECRANGE))
    --print(string.format('read %d', read_pct))

    if k <= read_pct then
        --print('READ')
        if l <= point_select_pct then
            --print('POINT')
            execute_point_id_select()
        else
            --print('RANGE')
            execute_selects(START,SECRANGE)
        end
    else
        --print('WRITE')
        if m <= point_update_pct then
            execute_point_id_update()
        else
            execute_inserts(START,SECRANGE)
        end
            
    end
    --execute_updates()

    if not sysbench.opt.skip_trx then
        con:query("COMMIT")
        --print('commit')
    end
end

