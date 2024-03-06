module("luci.controller.cellscan", package.seeall)

function index()
    local page = entry({"admin", "modem", "cellscan"}, cbi("cellscan"), _("基站扫描"))
    page.dependent = true
end

