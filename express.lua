-- Express-like HTTP server Class
function express(tcpServe)
    if not tcpServer then
        tcpServer = net.createServer(net.TCP) 
    end
    
    local supportedMethods = {'GET','POST','PUT','DELETE','HEAD'};
    
    local expressInstance = {
        tcpServer = tcpServer;
        port = 80;
        routes = {};
        middlewares = {};
        listen = function(this, port)
            if port then
                this.port = port
            end
            this.tcpServer:listen(this.port,function(conn)
                conn:on('receive',function(conn, request)
                    local req = {raw=request}
                    local res = {send=function(d) conn:send(d) end;}
                    
                    -- Call middleware callbacks
                    local middlewareCallbacks = this.middlewares
                    local i = 1
                    function _next()
                        if i > #middlewareCallbacks then
                            return
                        end
                        local middlewareCallback = middlewareCallbacks[i]
                        i = i+1
                        middlewareCallback(req,res,_next)
                    end
                    _next()
                     
                    -- Call route callbacks
                    if this.routes['_ALL'] then
                        local routeCallbacks = this.routes['_ALL'][req.url]
                        for i = 1, #routeCallbacks do
                            local routeCallback = routeCallbacks[i]
                            routeCallback(req,res)
                        end
                    end
                    if this.routes[req.method] then
                        local routeCallbacks = this.routes[req.method][req.url]
                        print(req.method)
                        print(req.url)
                        for i = 1, #routeCallbacks do
                            local routeCallback = routeCallbacks[i]
                            routeCallback(req,res)
                        end
                    end
                     
                end)
            end)
        end;
        _addRoute = function(this, method, route, callback) -- internal function to add routes to the express instance
            if not this.routes[method] then
                this.routes[method] = {}
                this.routes[method][route] = {} 
            elseif not this.routes[method][route] then
                this.routes[method][route] = {}
            end
            table.insert(this.routes[method][route],callback) --callback(req,res)
            print(this.routes[method][route]) 
        end;
        use = function(this, callback) -- to add a middleware
            table.insert(this.middlewares,callback) --callback(req, res, next) 
        end;
        all = function(this, route, callback) --to register routes on all HTTP methods
            this:_addRoute('_ALL', route, callback)
        end;
    }
    
    -- dynamically generate class methods for every supported HTTP verb/method (get, post etc)
    for i = 1, #supportedMethods do
        local method = supportedMethods[i]
        expressInstance.routes[method] = {}
        expressInstance[method:lower()] = function(this, route, callback)
           this:_addRoute(method,route,callback) 
        end
    end

    -- HTTP request line middleware
    expressInstance:use(function(req,res,next)
        local url = req.raw:match("^%a+%s([^%s]+)%s")
        local method = req.raw:match("(^%a+)%s[^%s]+%s")
        req.url = url
        req.method = method
        next()
    end)
    
    return expressInstance
end

-- TODO add static serve

-- file.open(fileToServe)
-- local responseBody = file.read()
-- local contentLength = responseBody:len()
-- local responseHeader = "HTTP/1.1 " .. statusCode .. " " .. statusText .. "\r\nContent-Length: " .. contentLength .. "\r\nContent-Type: text/html"
-- local response = responseHeader .. "\r\n\r\n" .. responseBody
