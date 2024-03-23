module("luci.controller.cellscan", package.seeall)

function index()
    entry({"admin", "modem"}, firstchild(), _("模块"), 40).dependent=false
    entry({"admin", "modem", "cellscan"}, template("cellscan/cellscan"), _("基站扫描"), 80).dependent = true
    entry({"admin", "modem", "cellscan", "switch2"}, call("action_switch2"), nil)
end


function action_switch2()
    local sys = require "luci.sys"
    local http = require "luci.http"
    local confirm = http.formvalue("confirm")
    
    if confirm and confirm == "yes" then
        --sys.call("./usr/share/modem/keyPairCellScan.sh")
        luci.http.redirect(luci.dispatcher.build_url("admin", "modem", "cellscan"))
        os.execute("/usr/share/modem/keyPairCellScan.sh")
    else
        luci.http.redirect(luci.dispatcher.build_url("admin", "modem", "cellscan"))
    end
end


function parse_results()
    local results = {}
    local controller = {}
    -- Read and parse cellinfo file
    local cellinfo = io.open("/tmp/kpcellinfo", "r")
    if cellinfo then
        for line in cellinfo:lines() do
            local mode, operator, band, earfcn, pci, rsrp, rsrq = line:match('+QSCAN: "(.-)",(.-),(.-),(.-),(.-),(.-),(.+)')
            if mode and operator and earfcn and pci and rsrp and rsrq then
                table.insert(controller, {
                    mode = mode,
                    operator = operator,
                    band = band,
                    earfcn = earfcn,
                    pci = pci,
                    rsrp = rsrp,
                    rsrq = rsrq
                })
            end
        end
        cellinfo:close()
    else
        table.insert(controller, {
            mode = "wait for ctrl...",
            operator = "",
            band = "",
            earfcn = "",
            pci = "",
            rsrp = "",
            rsrq = ""
        })
    end
    return controller
end
