plugin = {}

local PLUGIN_NAME = "DNF"
local PLUGIN_VERSION = "0.1.0"
local REQUIRED_BINARY = "dnf"
local RPM_QUERY_FORMAT = "%{NAME}|%{VERSION}-%{RELEASE}|%{ARCH}|%{LICENSE}|%{SUMMARY}\\n"
local DNF_QUERY_FORMAT = "%{name}|%{version}-%{release}|%{arch}|%{reponame}|%{summary}\\n"
local DNF_RESOLVE_FORMAT = "%{name}|%{version}-%{release}|%{arch}|%{reponame}|%{license}|%{url}|%{summary}\\n"

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function empty_to_nil(value)
    local normalized = trim(value)
    if normalized == "" or normalized == "(none)" then
        return nil
    end
    return normalized
end

local function shell_quote(value)
    return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function get_field(value, key)
    if value == nil then
        return nil
    end

    local value_type = type(value)
    if value_type == "table" or value_type == "userdata" then
        local ok, field = pcall(function()
            return value[key]
        end)
        if ok then
            return field
        end
    end

    return nil
end

local function escape_pattern(value)
    return tostring(value or ""):gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
end

local function split_lines(value)
    local lines = {}
    for line in (tostring(value or "") .. "\n"):gmatch("(.-)\n") do
        table.insert(lines, line)
    end
    return lines
end

local function split_fields(line, expected)
    local fields = {}
    local input = tostring(line or "")
    local start_index = 1

    for index = 1, expected - 1 do
        local separator_index = string.find(input, "|", start_index, true)
        if separator_index == nil then
            fields[index] = string.sub(input, start_index)
            for tail_index = index + 1, expected do
                fields[tail_index] = ""
            end
            return fields
        end

        fields[index] = string.sub(input, start_index, separator_index - 1)
        start_index = separator_index + 1
    end

    fields[expected] = string.sub(input, start_index)
    return fields
end

local function emit_event(context, name, payload)
    if context == nil or context.events == nil then
        return
    end

    local fn = context.events[name]
    if type(fn) == "function" then
        fn(payload)
    end
end

local function begin_step(context, label)
    if context == nil or context.tx == nil then
        return
    end

    local fn = context.tx.begin_step
    if type(fn) == "function" then
        fn(label)
    end
end

local function tx_success(context)
    if context == nil or context.tx == nil then
        return
    end

    local fn = context.tx.success
    if type(fn) == "function" then
        fn()
    end
end

local function tx_failed(context, message)
    if context == nil or context.tx == nil then
        return
    end

    local fn = context.tx.failed
    if type(fn) == "function" then
        fn(message)
    end
end

local function run_command(context, command, rules)
    if context ~= nil and context.exec ~= nil and type(context.exec.run) == "function" then
        if rules ~= nil then
            return context.exec.run(command, rules)
        end
        return context.exec.run(command)
    end
    return reqpack.exec.run(command)
end

local function command_exists(binary)
    return reqpack.exec.run("command -v " .. shell_quote(binary) .. " >/dev/null 2>&1").success
end

local function dnf_exec_rules(label)
    return {
        initial = "transaction",
        rules = {
            {
                state = "transaction",
                source = "line",
                regex = "^Downloading Packages:$",
                ["repeat"] = false,
                actions = {
                    { type = "begin_step", label = label .. " download" },
                    { type = "progress", percent = "10" },
                },
            },
            {
                state = "transaction",
                source = "line",
                regex = "^Dependencies resolved%.$",
                ["repeat"] = false,
                actions = {
                    { type = "begin_step", label = label .. " resolve dependencies" },
                    { type = "progress", percent = "30" },
                },
            },
            {
                state = "transaction",
                source = "line",
                regex = "^Transaction Summary$",
                ["repeat"] = false,
                actions = {
                    { type = "progress", percent = "45" },
                },
            },
            {
                state = "transaction",
                source = "line",
                regex = "^Running transaction$",
                ["repeat"] = false,
                actions = {
                    { type = "begin_step", label = label .. " transaction" },
                    { type = "progress", percent = "75" },
                },
            },
            {
                state = "transaction",
                source = "line",
                regex = "^(Installed|Removed|Upgraded):\\s*$",
                ["repeat"] = false,
                actions = {
                    { type = "progress", percent = "95" },
                },
            },
            {
                state = "transaction",
                source = "line",
                regex = "^(Nothing to do\\.|Complete!)$",
                ["repeat"] = false,
                actions = {
                    { type = "progress", percent = "100" },
                },
            },
        },
    }
end

local function make_version(epoch, version, release)
    local current_version = trim(version)
    if current_version == "" then
        return nil
    end

    local current_release = trim(release)
    if current_release ~= "" and current_release ~= "(none)" then
        current_version = current_version .. "-" .. current_release
    end

    local current_epoch = trim(epoch)
    if current_epoch ~= "" and current_epoch ~= "0" and current_epoch ~= "(none)" then
        current_version = current_epoch .. ":" .. current_version
    end

    return current_version
end

local function strip_epoch(version)
    return trim(version):gsub("^%d+:", "")
end

local function requested_version(package)
    return trim(get_field(package, "version"))
end

local function version_matches(installed_version, requested_version)
    local current_version = strip_epoch(installed_version)
    local wanted_version = strip_epoch(requested_version)

    if current_version == "" or wanted_version == "" then
        return current_version ~= "" and wanted_version == ""
    end

    if current_version == wanted_version then
        return true
    end

    return current_version:match("^" .. escape_pattern(wanted_version) .. "%-") ~= nil
end

local function package_name(package)
    local name = get_field(package, "name")
    if name ~= nil then
        return trim(name)
    end

    return trim(package)
end

local function package_spec(package)
    local name = package_name(package)
    if name == "" then
        return ""
    end

    local version = requested_version(package)
    if version ~= "" then
        return name .. "-" .. version
    end

    return name
end

local function make_package_id(name, version, architecture)
    local normalized_name = trim(name)
    local normalized_version = trim(version)
    local normalized_architecture = trim(architecture)

    if normalized_name == "" then
        return nil
    end

    if normalized_version == "" then
        return normalized_name
    end

    if normalized_architecture ~= "" then
        return normalized_name .. "." .. normalized_architecture .. "@" .. normalized_version
    end

    return normalized_name .. "@" .. normalized_version
end

local function parse_installed_rows(stdout)
    local items = {}

    for _, line in ipairs(split_lines(stdout)) do
        local normalized_line = trim(line)
        if normalized_line ~= "" then
            local fields = split_fields(normalized_line, 5)
            local name = trim(fields[1])
            local version = trim(fields[2])
            local architecture = empty_to_nil(fields[3])

            table.insert(items, {
                name = name,
                version = version,
                latestVersion = version,
                installed = true,
                status = "installed",
                packageType = "rpm",
                architecture = architecture,
                license = empty_to_nil(fields[4]),
                summary = empty_to_nil(fields[5]),
                repository = "@System",
                packageId = make_package_id(name, version, architecture),
            })
        end
    end

    return items
end

local function parse_repoquery_rows(stdout)
    local items = {}

    for _, line in ipairs(split_lines(stdout)) do
        local normalized_line = trim(line)
        if normalized_line ~= "" then
            local fields = split_fields(normalized_line, 5)
            local name = trim(fields[1])
            local version = trim(fields[2])
            local architecture = empty_to_nil(fields[3])

            table.insert(items, {
                name = name,
                version = version,
                latestVersion = version,
                installed = false,
                status = "available",
                packageType = "rpm",
                architecture = architecture,
                repository = empty_to_nil(fields[4]),
                summary = empty_to_nil(fields[5]),
                packageId = make_package_id(name, version, architecture),
            })
        end
    end

    return items
end

local function parse_resolve_rows(stdout)
    local items = {}

    for _, line in ipairs(split_lines(stdout)) do
        local normalized_line = trim(line)
        if normalized_line ~= "" then
            local fields = split_fields(normalized_line, 7)
            local name = trim(fields[1])
            local version = trim(fields[2])
            local architecture = empty_to_nil(fields[3])

            table.insert(items, {
                name = name,
                version = version,
                latestVersion = version,
                installed = false,
                status = "available",
                packageType = "rpm",
                architecture = architecture,
                repository = empty_to_nil(fields[4]),
                license = empty_to_nil(fields[5]),
                homepage = empty_to_nil(fields[6]),
                summary = empty_to_nil(fields[7]),
                packageId = make_package_id(name, version, architecture),
            })
        end
    end

    return items
end

local function parse_info_blocks(stdout)
    local blocks = {}
    local current = nil
    local in_description = false

    local function push_current()
        if current == nil or next(current) == nil then
            return
        end

        if current._description ~= nil then
            current.Description = trim(table.concat(current._description, "\n"))
            current._description = nil
        end

        table.insert(blocks, current)
    end

    for _, line in ipairs(split_lines(stdout)) do
        local normalized_line = trim(line)

        if normalized_line == "" then
            if in_description and current ~= nil and current._description ~= nil and #current._description > 0 then
                table.insert(current._description, "")
            end
        elseif normalized_line == "Installed Packages" or normalized_line == "Available Packages" then
            push_current()
            current = { section = normalized_line, _description = {} }
            in_description = false
        elseif in_description and line:match("^%s") then
            table.insert(current._description, trim(line))
        else
            local key, value = line:match("^([^:][^:]*)%s*:%s*(.*)$")
            if key ~= nil then
                if current == nil then
                    current = { _description = {} }
                end

                key = trim(key)
                if key == "Description" then
                    current._description = {}
                    if trim(value) ~= "" then
                        table.insert(current._description, trim(value))
                    end
                    in_description = true
                else
                    current[key] = trim(value)
                    in_description = false
                end
            end
        end
    end

    push_current()
    return blocks
end

local function build_info_item(blocks)
    local installed_block = nil
    local available_block = nil

    for _, block in ipairs(blocks or {}) do
        if installed_block == nil and (block.section == "Installed Packages" or block["Install Date"] ~= nil or block.Repository == "@System") then
            installed_block = block
        elseif available_block == nil then
            available_block = block
        end
    end

    local primary = installed_block or available_block
    if primary == nil then
        return nil
    end

    local fallback = available_block or installed_block
    local item = {
        name = empty_to_nil(primary.Name),
        version = make_version(primary.Epoch, primary.Version, primary.Release),
        latestVersion = fallback ~= nil and make_version(fallback.Epoch, fallback.Version, fallback.Release) or nil,
        installed = installed_block ~= nil,
        status = installed_block ~= nil and "installed" or "available",
        packageType = "rpm",
        architecture = empty_to_nil(primary.Architecture),
        summary = empty_to_nil(primary.Summary),
        description = empty_to_nil(primary.Description),
        homepage = empty_to_nil(primary.URL),
        license = empty_to_nil(primary.License),
        repository = empty_to_nil(primary["From repo"] or primary.Repository),
    }

    if item.latestVersion == nil then
        item.latestVersion = item.version
    end
    if item.repository == nil and fallback ~= nil then
        item.repository = empty_to_nil(fallback["From repo"] or fallback.Repository)
    end

    local source_rpm = empty_to_nil(primary["Source RPM"])
    if source_rpm == nil and fallback ~= nil then
        source_rpm = empty_to_nil(fallback["Source RPM"])
    end
    if source_rpm ~= nil then
        item.extraFields = { sourceRpm = source_rpm }
    end

    item.packageId = make_package_id(item.name, item.version, item.architecture)
    return item
end

local function build_command_args(packages, formatter)
    local args = {}

    for _, package in ipairs(packages or {}) do
        local spec = trim(formatter(package))
        if spec ~= "" then
            table.insert(args, shell_quote(spec))
        end
    end

    return table.concat(args, " ")
end

local function query_installed_version(name)
    local result = reqpack.exec.run("rpm -q --queryformat '%{VERSION}-%{RELEASE}\\n' " .. shell_quote(name))
    if not result.success then
        return nil
    end

    local version = trim(result.stdout)
    if version == "" then
        return nil
    end
    return version
end

local function is_installed(package)
    local name = package_name(package)
    if name == "" then
        return false
    end

    if requested_version(package) ~= "" then
        local installed_version = query_installed_version(name)
        return version_matches(installed_version, requested_version(package))
    end

    return reqpack.exec.run("rpm -q " .. shell_quote(name) .. " >/dev/null 2>&1").success
end

local function has_update(package)
    local name = package_name(package)
    if name == "" then
        return false
    end

    local result = reqpack.exec.run("dnf check-update -q " .. shell_quote(name))
    if result.success then
        return false
    end

    return tonumber(result.exitCode) == 100
end

local function run_mutation(context, label, command, event_name, payload, failure_message)
    begin_step(context, label)

    local result = run_command(context, command, dnf_exec_rules(label))
    if not result.success then
        tx_failed(context, failure_message)
        return false
    end

    emit_event(context, event_name, payload)
    tx_success(context)
    return true
end

local function empty_result(context, event_name)
    local items = {}
    emit_event(context, event_name, items)
    return items
end

local function pick_resolved_item(package, items)
    local name = package_name(package)
    local version = requested_version(package)
    local relaxed_match = nil

    for _, item in ipairs(items or {}) do
        if name == "" or item.name == name then
            if version == "" then
                return item
            end

            if strip_epoch(item.version) == strip_epoch(version) then
                return item
            end

            if relaxed_match == nil and version_matches(item.version, version) then
                relaxed_match = item
            end
        end
    end

    return relaxed_match
end

local function resolved_info_item_matches(package, item)
    if type(item) ~= "table" or item.name == nil then
        return false
    end

    local name = package_name(package)
    if name ~= "" and trim(item.name) ~= name then
        return false
    end

    local version = requested_version(package)
    if version ~= "" and not version_matches(item.version, version) then
        return false
    end

    return true
end

plugin.fileExtensions = { ".rpm" }

function plugin.getName()
    return PLUGIN_NAME
end

function plugin.getVersion()
    return PLUGIN_VERSION
end

function plugin.getRequirements()
    return {}
end

function plugin.getCategories()
    return { "System", "RPM", "Wrapper" }
end

function plugin.getMissingPackages(packages)
    local missing = {}

    for _, package in ipairs(packages or {}) do
        local action = trim(get_field(package, "action"))

        if action == "remove" then
            if is_installed(package) then
                table.insert(missing, package)
            end
        elseif action == "update" then
            if has_update(package) then
                table.insert(missing, package)
            end
        elseif not is_installed(package) then
            table.insert(missing, package)
        end
    end

    return missing
end

function plugin.install(context, packages)
    local args = build_command_args(packages, package_spec)
    if args == "" then
        return true
    end

    return run_mutation(
        context,
        "install DNF packages",
        "dnf install -y " .. args,
        "installed",
        packages or {},
        "dnf install failed"
    )
end

function plugin.installLocal(context, path)
    local local_path = trim(path)
    if local_path == "" then
        tx_failed(context, "local package path missing")
        return false
    end

    return run_mutation(
        context,
        "install local RPM artifact",
        "dnf install -y " .. shell_quote(local_path),
        "installed",
        { path = local_path, localTarget = true },
        "dnf local install failed"
    )
end

function plugin.remove(context, packages)
    local args = build_command_args(packages, function(package)
        if requested_version(package) == "" then
            return package_name(package)
        end
        return package_spec(package)
    end)

    if args == "" then
        return true
    end

    return run_mutation(
        context,
        "remove DNF packages",
        "dnf remove -y " .. args,
        "deleted",
        packages or {},
        "dnf remove failed"
    )
end

function plugin.update(context, packages)
    local args = build_command_args(packages, function(package)
        return package_name(package)
    end)

    if args == "" then
        return true
    end

    return run_mutation(
        context,
        "update DNF packages",
        "dnf upgrade -y " .. args,
        "updated",
        packages or {},
        "dnf upgrade failed"
    )
end

function plugin.list(context)
    local result = run_command(context, "rpm -qa --queryformat " .. shell_quote(RPM_QUERY_FORMAT))
    if not result.success then
        return empty_result(context, "listed")
    end

    local items = parse_installed_rows(result.stdout)
    emit_event(context, "listed", items)
    return items
end

function plugin.outdated(context)
    local result = run_command(
        context,
        "dnf repoquery --upgrades --queryformat " .. shell_quote(DNF_QUERY_FORMAT)
    )
    if not result.success then
        return empty_result(context, "outdated")
    end

    local items = parse_repoquery_rows(result.stdout)
    for _, item in ipairs(items) do
        local installed_version = query_installed_version(item.name)
        if installed_version ~= nil then
            item.latestVersion = item.version
            item.version = installed_version
            item.installed = true
            item.status = "upgradable"
            item.packageId = make_package_id(item.name, item.version, item.architecture)
        end
    end

    emit_event(context, "outdated", items)
    return items
end

function plugin.search(context, prompt)
    local query = trim(prompt)
    if query == "" then
        return empty_result(context, "searched")
    end

    local result = run_command(
        context,
        "dnf repoquery --available --latest-limit 1 --queryformat " .. shell_quote(DNF_QUERY_FORMAT) .. " " .. shell_quote("*" .. query .. "*")
    )
    if not result.success then
        return empty_result(context, "searched")
    end

    local items = parse_repoquery_rows(result.stdout)
    emit_event(context, "searched", items)
    return items
end

function plugin.info(context, name)
    local query = trim(name)
    if query == "" then
        emit_event(context, "informed", {})
        return {}
    end

    local blocks = {}
    local installed_result = run_command(context, "rpm -qi " .. shell_quote(query))
    if installed_result.success then
        blocks = parse_info_blocks(installed_result.stdout)
    else
        local available_result = run_command(context, "dnf info -q " .. shell_quote(query))
        if available_result.success then
            blocks = parse_info_blocks(available_result.stdout)
        end
    end

    local item = build_info_item(blocks)
    if item == nil then
        emit_event(context, "informed", {})
        return {}
    end

    emit_event(context, "informed", item)
    return item
end

function plugin.resolvePackage(context, package)
    local name = package_name(package)
    if name == "" then
        return nil
    end

    local version = requested_version(package)
    local command = "dnf repoquery "
    if version == "" then
        command = command .. "--latest-limit 1 "
    end

    local spec = version ~= "" and package_spec(package) or name
    command = command .. "--queryformat " .. shell_quote(DNF_RESOLVE_FORMAT) .. " " .. shell_quote(spec)

    local result = run_command(context, command)
    if result.success then
        local resolved = pick_resolved_item(package, parse_resolve_rows(result.stdout))
        if resolved ~= nil then
            return resolved
        end
    end

    local info_result = plugin.info(context, package_name(package))
    if resolved_info_item_matches(package, info_result) then
        return info_result
    end

    return nil
end

function plugin.getSecurityMetadata()
    return {
        role = "package-manager",
        capabilities = { "exec", "network" },
        ecosystemScopes = { "rpm" },
        writeScopes = {
            { kind = "temp" },
        },
        privilegeLevel = "sudo",
        osvEcosystem = "RPM",
        purlType = "rpm",
        versionComparatorProfile = "rpm-evr",
        versionTokenPattern = "[A-Za-z0-9._+~:-]+",
        versionCaseInsensitive = false,
    }
end

function plugin.init()
    return command_exists(REQUIRED_BINARY)
end

function plugin.shutdown()
    return true
end

return plugin
