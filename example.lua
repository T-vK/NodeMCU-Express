require('HttpServer')

-- If you want to connect to the ESP's own WiFi AP:
local ESP_WIFI_NETWORK_NAME = 'HttpServerTest'
local ESP_WIFI_NETWORK_PASSWORD = 'test12345' -- at least 8 characters
local ESP_IP = '192.168.11.1'

-- If you want the ESP to connect to your WiFi network:
local YOUR_WIFI_NETWORK_NAME = 'YourHomeWifi'
local YOUR_WIFI_NETWORK_PASSWORD = 'abcdefgh'

-- This script will print its IP addresses to the serial console. 
-- Then you just type http://`THE-IP-ADDRESS`/helloworld into your browser-

-----------------------------------------------------------------------------
-------------------------------- WIFI SETUP ---------------------------------
-----------------------------------------------------------------------------
local wifiConfig = {}

wifiConfig.mode = wifi.STATIONAP --wifi.STATIONAP --wifi.STATION --wifi.SOFTAP

if wifiConfig.mode == wifi.SOFTAP or wifiConfig.mode == wifi.STATIONAP then
    wifiConfig.accessPointConfig = {}
    wifiConfig.accessPointConfig.ssid = ESP_WIFI_NETWORK_NAME
    wifiConfig.accessPointConfig.pwd =  ESP_WIFI_NETWORK_PASSWORD

    wifiConfig.accessPointIpConfig = {}
    wifiConfig.accessPointIpConfig.ip = ESP_IP
    wifiConfig.accessPointIpConfig.netmask = "255.255.255.0"
    wifiConfig.accessPointIpConfig.gateway = ESP_IP
end

if wifiConfig.mode == wifi.STATION or wifiConfig.mode == wifi.STATIONAP then
    wifiConfig.stationConfig = {}
    wifiConfig.stationConfig.ssid = YOUR_WIFI_NETWORK_NAME
    wifiConfig.stationConfig.pwd =  YOUR_WIFI_NETWORK_PASSWORD
end

wifi.setmode(wifiConfig.mode)

if wifiConfig.mode == wifi.SOFTAP or wifiConfig.mode == wifi.STATIONAP then
    print('AP MAC: ' .. wifi.ap.getmac())
    print('AP IP: ' .. ESP_IP)
    wifi.ap.config(wifiConfig.accessPointConfig)
    wifi.ap.setip(wifiConfig.accessPointIpConfig)
    wifi.ap.dhcp.start()
    wifi.eventmon.register(wifi.eventmon.AP_STACONNECTED, function(T)
        print("New client connecting to the ESP...")
    end)
    print("HttpServer will be available at http://" .. wifi.ap.getip() .. "/ once you connect to the '" .. ESP_WIFI_NETWORK_NAME .. "' WiFi.")
end

if wifiConfig.mode == wifi.STATION or wifiConfig.mode == wifi.STATIONAP then
    print('Client MAC: ' .. wifi.sta.getmac())
    wifi.sta.config(wifiConfig.stationConfig.ssid, wifiConfig.stationConfig.pwd, 1)

    wifi.sta.eventMonReg(wifi.STA_WRONGPWD, function() print("The password for " .. YOUR_WIFI_NETWORK_NAME .. " is incorrect.") end)
    wifi.sta.eventMonReg(wifi.STA_APNOTFOUND, function() print("Couldn't find " .. YOUR_WIFI_NETWORK_NAME .. ".") end)
    wifi.sta.eventMonReg(wifi.STA_FAIL, function() print("Failed to connect to " .. YOUR_WIFI_NETWORK_NAME .. ".") end)
    wifi.sta.eventMonReg(wifi.STA_GOTIP, function() 
        print("Successfully connected to " .. YOUR_WIFI_NETWORK_NAME .. ".")
        print("Client IP: " .. wifi.sta.getip())
        print("HttpServer will be available at http://" .. wifi.sta.getip() .. "/ if you are in the '" .. YOUR_WIFI_NETWORK_NAME .. "' network.")
    end)
end

wifi.sta.eventMonStart()

-------------------------------------------------------------------------------------------



-------------------------------------------------------------------------------------------
---------------------------------------HTTP server-----------------------------------------
-------------------------------------------------------------------------------------------

local app = express.new()
app:listen(80)

-- Register a new middleware that prints the url of every request
app:use(function(req,res,next) 
    print(req.url)
    next()
end)

-- Register a new route that just returns an html site that says "HELLO WORLD!"
app:get('/helloworld',function(req,res)
    res:send('<html><head></head><body>HELLO WORLD!</body></html>')
end)

-- Serve the file `home.html` when visiting `/home`
app:use('/home',express.static('home.html'))

-- Serve all files that are in the folder `http` at url `/libs/...`
-- (To be more accurate I'm talking about all files starting with `http/`.)
app:use('/libs',express.static('http'))

-------------------------------------------------------------------------------------------
