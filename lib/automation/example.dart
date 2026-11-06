const automationExample =
    '''-- Rename courses and hide old-platform deadlines for selected courses.
function filter(data)
    local aliases = {
        ["某个非常长的课程名称"] = "简称",
    }

    for _, course in ipairs(data.courses) do
        course.name = aliases[course.name] or course.name
    end

    local deadlines = {}
    for _, ddl in ipairs(data.deadlines) do
        local ignored =
            ddl.source == "lexue"
            and ddl.course == "某门课程"

        if not ignored then
            ddl.course = aliases[ddl.course] or ddl.course
            table.insert(deadlines, ddl)
        end
    end

    data.deadlines = deadlines
    return data
end
''';
