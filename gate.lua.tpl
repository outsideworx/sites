local password = "{{GATE_PASSWORD}}"
local gate_path = "{{GATE_PATH}}"
local cookie_name = "gate_token"
local cookie_value = "granted"

function check_access(r)
    if r.uri == gate_path .. "gate" then
        return handle_gate(r)
    end
    local cookies = r.headers_in["Cookie"] or ""
    if cookies:match(cookie_name .. "=" .. cookie_value) then
        return apache2.DECLINED
    end
    r.headers_out["Location"] = gate_path .. "gate"
    r.status = 302
    return apache2.DONE
end

function handle_gate(r)
    if r.method == "POST" then
        local body = r:requestbody()
        local submitted = nil
        if body then
            submitted = body:match("password=([^&]*)")
            if submitted then
                submitted = submitted:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
                submitted = submitted:gsub("+", " ")
            end
        end
        if submitted == password then
            r.headers_out["Set-Cookie"] = cookie_name .. "=" .. cookie_value .. "; Path=" .. gate_path .. "; HttpOnly; SameSite=Strict"
            r.headers_out["Location"] = gate_path
            r.status = 302
            return apache2.DONE
        end
        r.status = 200
        r.content_type = "text/html"
        r:write(get_form("Incorrect password"))
        return apache2.DONE
    end
    r.status = 200
    r.content_type = "text/html"
    r:write(get_form(nil))
    return apache2.DONE
end

function get_form(err)
    local error_html = ""
    if err then
        error_html = '<p style="color:#c0392b">' .. err .. '</p>'
    end
    return [[<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Access</title>
<style>
body{display:flex;align-items:center;justify-content:center;min-height:100vh;margin:0;background:#111;color:#eee;font-family:sans-serif}
.card{text-align:center;background:#1a1a1a;padding:2.5em;border-radius:8px;border:1px solid #333;min-width:300px}
h1{margin:0 0 .5em;font-size:1.5em;font-weight:600}
p.hint{color:#999;margin:0 0 1.5em;font-size:.9em}
input[type=password]{padding:.5em;font-size:1em;border:1px solid #555;border-radius:4px;background:#222;color:#eee;width:100%;box-sizing:border-box}
button{padding:.5em 1.5em;font-size:1em;border:none;border-radius:4px;background:#00b2ff;color:#111;cursor:pointer;margin-top:1em}
</style>
</head>
<body>
<form method="POST" class="card">
<h1>Outside Worx</h1>
<p class="hint">Please provide your client secret to continue.</p>
]] .. error_html .. [[
<input type="password" name="password" placeholder="Client secret" autofocus>
<br>
<button type="submit">Enter</button>
</form>
</body>
</html>]]
end
