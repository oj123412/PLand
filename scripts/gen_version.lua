function main()
    -- 创建include/pland目录（如果不存在）
    os.mkdir("include/pland")

    -- 获取当前提交的哈希值（这个命令总是可用的）
    local commit_hash = os.iorunv("git", {"rev-parse", "--short=7", "HEAD"}) or "unknown"
    commit_hash = commit_hash:gsub("\n", ""):gsub("\r", "")

    -- 默认版本信息（无tag情况）
    local latest_tag = "v0.0.0"
    local major, minor, patch = 0, 0, 0
    local build_number = 0
    local is_snapshot = true
    local has_tags = false

    -- 尝试获取Git标签列表来检查是否有标签
    local tag_list = os.iorunv("git", {"tag", "--list"})
    if tag_list and tag_list ~= "" and not tag_list:find("fatal:") and not tag_list:find("2>") then
        has_tags = true
        -- 尝试获取最新的tag
        local tag_result = os.iorunv("git", {"describe", "--tags", "--abbrev=0"})
        if tag_result and tag_result ~= "" and not tag_result:find("fatal:") and not tag_result:find("2>") then
            latest_tag = tag_result:gsub("\n", ""):gsub("\r", "")
        else
            has_tags = false
        end
    end

    if not has_tags then
        print("No Git tags found, using default version v0.0.0")
    end

    -- 解析版本号
    if has_tags then
        local tag_major, tag_minor, tag_patch = latest_tag:match("v(%d+)%.(%d+)%.(%d+)")
        major = tonumber(tag_major or "0")
        minor = tonumber(tag_minor or "0")
        patch = tonumber(tag_patch or "0")
    end

    -- 获取提交数量
    if not has_tags then
        -- 没有tag的情况，获取总提交数
        local total_commits = os.iorunv("git", {"rev-list", "--count", "HEAD"})
        if total_commits and total_commits ~= "" then
            local clean_commits = total_commits:gsub("\n", ""):gsub("\r", "")
            build_number = tonumber(clean_commits) or 0
        end
    else
        -- 有tag的情况，获取从tag到当前的提交数
        local commits_since_tag = os.iorunv("git", {"rev-list", latest_tag .. "..HEAD", "--count"})
        if commits_since_tag and commits_since_tag ~= "" then
            local clean_commits = commits_since_tag:gsub("\n", ""):gsub("\r", "")
            build_number = tonumber(clean_commits) or 0
        end

        -- 检查是否是快照版本
        local tag_hash = os.iorunv("git", {"rev-list", "-n", "1", latest_tag})
        if tag_hash and tag_hash ~= "" and not tag_hash:find("fatal:") then
            tag_hash = tag_hash:gsub("\n", ""):gsub("\r", "")
            if #tag_hash >= 7 then
                is_snapshot = (commit_hash ~= tag_hash:sub(1, 7))
            end
        end
    end
    
    -- 生成版本字符串
    local version_type = is_snapshot and "Snapshot" or "Release"
    local version_string = string.format("[%s] %s-%s+%d", version_type, latest_tag, commit_hash, build_number)
    
    -- 生成Version.h文件内容
    local content = string.format([[#pragma once

// 自动生成的版本信息，请勿手动修改
// Auto-generated version information, do not modify manually

// 主版本号
#define PLAND_VERSION_MAJOR %d

// 次版本号
#define PLAND_VERSION_MINOR %d

// 修订号
#define PLAND_VERSION_PATCH %d

// 编译号（从tag起算）
#define PLAND_VERSION_BUILD %d

// 最近一次的提交哈希
#define PLAND_COMMIT_HASH "%s"

// 是否是快照版本
#define PLAND_VERSION_SNAPSHOT %s

// 是否是正式发布版本
#define PLAND_VERSION_RELEASE !PLAND_VERSION_SNAPSHOT

// 完整版本字符串
#define PLAND_VERSION_STRING "%s"
]], 
        major, minor, patch, build_number, commit_hash, 
        is_snapshot and "true" or "false", version_string)
    
    -- 写入文件
    local file = io.open("include/pland/Version.h", "w")
    if file then
        file:write(content)
        file:close()
        print("Generated Version.h: " .. version_string)
    else
        print("Failed to write Version.h")
    end
end

return main