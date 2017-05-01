-- Express.js-like HTTP server Class
express = {
    new = function(tcpServe)
        if not tcpServer then
            tcpServer = net.createServer(net.TCP) 
        end
        
        local defaultPort = 80
        local supportedMethods = {'GET','POST','PUT','DELETE','HEAD'}
        local statusCodes = {
            [200] = 'OK',
            [201] = 'Created',
            [204] = 'No Content',
            [301] = 'Moved Permanently',
            [302] = 'Found',
            [303] = 'See Other',
            [304] = 'Not Modified',
            [400] = 'Bad Request',
            [401] = 'Unauthorized',
            [402] = 'Forbidden',
            [404] = 'Not Found',
            [409] = 'Conflict',
            [500] = 'Internal Server Error' 
        }
        local defaultHeaders = {
            ['Content-Type'] = 'text/html',
        }
        local defaultStatusCode = 200
        local defaultHttpVersion = 'HTTP/1.1'

        local expressInstance = {
            tcpServer = tcpServer;
            port = defaultPort;
            statusCodes = statusCodes;
            defaultStatusCode = defaultStatusCode;
            defaultHeaders = defaultHeaders;
            defaultHttpVersion = defaultHttpVersion; 
            routes = {};
            middlewares = {};
            listen = function(this, port, ip)
                if port then
                    this.ip = ip
                    this.port = port
                end
                this.tcpServer:listen(this.port,function(conn)
                    conn:on('receive',function(conn, rawRequest)
                        local req = {
                            app=this;
                            route={};
                            raw=rawRequest;
                            url=rawRequest:match("^%a+%s([^%s]+)%s");
                            method=rawRequest:match("^(%a+)%s[^%s]+%s");
                            httpVersion=rawRequest:match("^%a+%s[^%s]+%s([^\r]+)\r");
                        }
                        local res = {
                            app = this;
                            sendRaw = function(this,rawRes)
                                conn:send(rawRes)
                            end;
                            _headers = this.defaultHeaders;
                            statusCode = this.defaultStatusCode;
                            statusText = this.statusCodes[this.defaultStatusCode];
                            httpVersion = this.defaultHttpVersion;
                        }
                        
                        -- Call middleware callbacks 
                        local middlewareCallbacksMaster = {} -- all middlewares that need to be called
                        for i = 1, #this.middlewares do
                            local middleware = this.middlewares[i]
                            local route = middleware.route
                            local callback = middleware.callback
                            
                            if string.sub(req.url,1,string.len(route)) == route then -- if url matches route pattern
                            print("route added")
                                middlewareCallbacksMaster[#middlewareCallbacksMaster+1] = callback
                            end
                        end
                        local i = 1
                        function _next()
                            if i > #middlewareCallbacksMaster then
                                return
                            end
                            local middlewareCallback = middlewareCallbacksMaster[i]
                            i = i+1
                            middlewareCallback(req,res,_next)
                        end
                        _next()

                        -- Call route callbacks
                        local methodsToCheck = {'_ALL',req.method}
                        for i = 1, #methodsToCheck do
                            local method = methodsToCheck[i]
                            if this.routes[method] then
                                for route, routeCallbacks in pairs(this.routes[method]) do
                                    if string.sub(req.url,1,string.len(route)) == route then -- if url matches route pattern
                                        for j = 1, #routeCallbacks do
                                            local routeCallback = routeCallbacks[j]
                                            routeCallback(req,res)
                                        end
                                   end
                                end
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
            end;
            use = function(this, route, callback) -- to add a middleware
                if callback == nil then
                    callback = route
                    route = '/'
                end
                this.middlewares[#this.middlewares+1] = {["callback"]=callback, ["route"]=route} --callback(req, res, next) 
            end;
            all = function(this, route, callback) --to register routes on all HTTP methods
                this:_addRoute('_ALL', route, callback)
            end;
        }
        
        -- Dynamically generate class methods for every supported HTTP verb/method (get, post etc)
        for i = 1, #supportedMethods do
            local method = supportedMethods[i]
            expressInstance.routes[method] = {}
            expressInstance[method:lower()] = function(this, route, callback)
               this:_addRoute(method,route,callback) 
            end
        end
        
        
        ------------------------------------------------------
        --------------- BUILT-IN MIDDLEWARES -----------------
        ------------------------------------------------------

       
        -- Response generator
        expressInstance:use(function(req,res,next)
            -- Allows setting headers
            res.set = function(this,key,value)
                if value == nil then
                    value = ''
                end
                this._headers[key] = value
                return this
            end
            -- Allow removing headers
            res.removeHeader = function(this,key)
                this.headers[key] = nil
                return this
            end
            -- Allow setting response code
            res.status = function(this,code)
                this.statusCode = code
                this.statusText = res.app.statusCodes[code]
                return this
            end
            -- Allow sending body (string or if supported table which get converted to json)i
            res.send = function(this,body)
                if type(body) == 'table' then
                    body = cjson.encode(body)
                    this:set('Content-Type', 'application/json')
                end
                
                local rawResponse = this.httpVersion .. ' ' .. this.statusCode .. ' ' .. this.statusText .. '\r\n'
                
                if body and this._headers['Content-Length'] == nil then
                    this:set('Content-Length', string.len(body))
                end
                
                for key, value in pairs(this._headers) do
                    rawResponse = rawResponse .. key .. ': ' .. value .. '\r\n'
                end
                                
                rawResponse = rawResponse .. '\r\n' .. body
                
                this:sendRaw(rawResponse)
            end
            -- Dedicated function for json body
            res.json = function(this,table)
                res:send(table)
            end
            
            next()
        end) 
        
        return expressInstance
    end;

    -- Returns middleware to server static files 
    static = function(basePath)
        if string.sub(basePath,1,1) == '/' then
            basePath = string.sub(basePath,2) -- remove leading '/'
        end

        local middleware = function(req,res,next)
            local fileToServePath = basePath
            if not file.exists(basePath) then
                local urlLen = string.len(req.url)
                local baseLen = string.len(basePath)
                fileToServePath = basePath .. string.sub(req.url,-(urlLen-baseLen+2))
            end
            print(fileToServePath)
            if file.exists(fileToServePath) then
                local fileToServe = file.open(fileToServePath, 'r')
                if fileToServe then
                    res:send(fileToServe:read())
                    fileToServe:close()
                    fileToServe = nil
                end
            end
            next()
        end
        
        return middleware
    end;
}
