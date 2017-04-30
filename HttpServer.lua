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
            listen = function(this, port)
                if port then
                    this.port = port
                end
                this.tcpServer:listen(this.port,function(conn)
                    conn:on('receive',function(conn, rawRequest)
                        local req = {
                            app=this;
                            route={};
                            raw=rawRequest;
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
                        if this.routes['_ALL'] and this.routes['_ALL'][req.url] then
                            local routeCallbacks = this.routes['_ALL'][req.url]
                            for i = 1, #routeCallbacks do
                                local routeCallback = routeCallbacks[i]
                                routeCallback(req,res)
                            end
                        end
                        if this.routes[req.method] and this.routes[req.method][req.url] then
                            local routeCallbacks = this.routes[req.method][req.url]
                            
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
        
        
        ------------------------------------------------------
        --------------- BUILT-IN MIDDLEWARES -----------------
        ------------------------------------------------------

        -- Request line parser
        expressInstance:use(function(req,res,next)
            local url = req.raw:match("^%a+%s([^%s]+)%s")
            local method = req.raw:match("^(%a+)%s[^%s]+%s")
            local httpVersion = req.raw:match("^%a+%s[^%s]+%s([^\r]+)\r")
            
            req.url = url
            req.method = method
            req.httpVersion = httpVersion

            next()
        end)
        
        -- Response generator
        expressInstance:use(function(req,res,next)
            -- allows setting headers
            res.set = function(this,key,value)
                if value == nil then
                    value = ''
                end
                this._headers[key] = value
                return this
            end
            -- allow removing headers
            res.removeHeader = function(this,key)
                this.headers[key] = nil
                return this
            end
            -- allow setting response code
            res.status = function(this,code)
                this.statusCode = code
                this.statusText = res.app.statusCodes[code]
                return this
            end
            -- allow sending body (string or if supported table which get converted to json)
            res.send = function(this,body)
                if type(body) == 'table' then
                    body = cjson.encode(body)
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
            -- dedicated function for json body
            res.json = function(this,table)
                res:send(cjson.encode(table))
            end
            
            next()
        end) 
        
        -- body parser  
        
        
        return expressInstance
    end;

    -- Static method to serve static files
    --[[
    static = function(path)
        -- TODO: scan for all files starting with or being path

        let route = function(req,res,next)
            if req.url then
                res:send()
            end
            next()
        end
        return
    end;
    ]]
}

-- TODO add static serve

-- file.open(fileToServe)
-- local responseBody = file.read()
-- local contentLength = responseBody:len()
-- local responseHeader = "HTTP/1.1 " .. statusCode .. " " .. statusText .. "\r\nContent-Length: " .. contentLength .. "\r\nContent-Type: text/html"
-- local response = responseHeader .. "\r\n\r\n" .. responseBody
