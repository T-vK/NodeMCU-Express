# Awesome HTTP server library for ESP8266 modules that run the NodeMCU firmware

## About
This HTTP server library is very similar to the popular node.js express module.  
I'm trying to make the interface as similar as possible.  
For now I'm only going to add functionality for adding routes, middlewares and to serve static files.  
By creating your own middlewares you can then easily extend the functionality as far as your heart desires.  
I will create an http header middleware and a body parser middleware as I will definitely need those. 

# Example
``` Lua
require('express')
local app = express()
app:listen(80) -- listen on port 80

-- create a new middleware that prints the url of every request
app:use(function(req,res,next) 
    print(url)
    next()
end)

-- create a new middleware that prints the url of every request
app:get('/home',function(req,res)
    local statusCode = 200
    local statusText = 'OK'
    local responseBody = '<html><head></head><body>HELLO WORLD!</body></html>'
    local contentLength = responseBody:len()
    local responseHeader = "HTTP/1.1 " .. statusCode .. " " .. statusText .. "\r\nContent-Length: " .. contentLength .. "\r\nContent-Type: text/html"
    local response = responseHeader .. "\r\n\r\n" .. responseBody
    res:send(response)
end)
```
