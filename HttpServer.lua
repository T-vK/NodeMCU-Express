-- Express.js-like HTTP server Class
do
    local express = {
        statusCodes = {
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
            [500] = 'Internal Server Error',
        },
        defaults = {
            port = 80,
            headers = {
                ['Content-Type'] = 'text/html',
            },
            statusCode = 200,
            httpVersion = 'HTTP/1.1',
        },
        instanceMetaTable = {
            __index = function(t,method) -- Magic to allow all HTTP methods
                return function(this, route, callback)
                   return this:_addRoute(method:upper(), route, callback)
                end
            end, 
        },
        -- Returns a middleware to serve static files 
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
        end,
                
        middleware = { --  BUILT-IN MIDDLEWARES
          --[[  
            statusLineMethods = function(req,res,next)
                -- Allow setting response code/text
                res.status = function(this,code)
                    this.statusCode = code
                    this.statusText = res.app.statusCodes[code]
                    return this
                end
                next()
            end,
            
            responseHeaderMethods = function(req,res,next)
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
                next()
            end,
            
            responseBodyMethods = function(req,res,next)
                -- Allow sending body (string or if supported table which get converted to json)i
                res.send = function(this,body)
                    if type(body) == 'table' then -- TODO: change this to form url encoding?
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
                --  Allow sending lua table encoded as json
                res.json = function(this,table)
                    body = cjson.encode(table)
                    this:set('Content-Type', 'application/json')
                    res:send(body)
                end
                next()
            end, 
            
            requestParser = function(req,res,next)
                req.rawBody = req.raw -- We'll strip it down until the body is left
                while true do -- Parse headers into table
                    local startPos, endPos, key, value = string.find(req.rawBody, "\r\n([^:]+):%s([^\r]+)\r\n")
                    if not key then
                        break
                    end
                    req.headers[key] = value
                    req.rawBody = string.sub(req.rawBody,endPos-1)
                end
                req.rawBody = string.sub(req.rawBody,5)
                
                req.get = function(this,key)
                    return this.headers[key]
                end
                next()
            end,
            
            jsonParser = function(req,res,next)
                if req.headers['Content-Type'] and string.match(req.headers['Content-Type'], 'application/json') then
                    req.body = cjson.decode(req.rawBody)
                    req.rawBody = nil -- let's save the memory
                end
                next()
            end,
            
            bodyFormDataParser = function(req,res,next)
                if req.headers['Content-Type'] and string.match(req.headers['Content-Type'], 'application/x-www-form-urlencoded') then
                    while true do
                        local startPos, endPos, key, value = string.find(req.rawBody, '^([^=]+)=([^&]+)&*')
                        if not key then
                            break
                        end
                        req.body[key] = value
                        req.rawBody = string.sub(req.rawBody,endPos+1)
                    end
                    req.rawBody = nil -- let's save the memory
                end
                next()
            end,
            
            urlDecodeBodyParams = function(req,res,next)
                if req.headers['Content-Type'] and string.match(req.headers['Content-Type'], 'application/x-www-form-urlencoded') then
                    local unescape = function(s) -- Credits to TerryE
                        local rt, i, len = "", 1, #s
                        s = s:gsub('+', ' ')
                        local j, xx = s:match('()%%(%x%x)', i)
                        while j do
                            rt = rt .. s:sub(i, j-1) .. string.char(tonumber(xx,16))
                            i = j+3
                            j, xx = s:match('()%%(%x%x)', i)
                        end
                        return rt .. s:sub(i)
                    end
                    
                    for key, value in pairs(req.body) do
                        req.body[key] = unescape(value)
                    end
                end
                next()
            end,
        ]]
        }
    }

    setmetatable(express, {
        __call = function(tcpServe) -- Class Constructor 
            if not tcpServer then
                tcpServer = net.createServer(net.TCP) 
            end
            local expressInstance = {
                tcpServer = tcpServer,
                port = express.defaults.port,
                statusCodes = express.statusCodes,
                defaultStatusCode = express.defaults.statusCode,
                defaultHeaders = express.defaults.headers,
                defaultHttpVersion = express.defaults.httpVersion,
                routes = {},
                middlewares = {},
                listen = function(this, port, ip)
                    if port then
                        this.ip = ip
                        this.port = port
                    end
                    this.tcpServer:listen(this.port,function(conn)
                        conn:on('receive',function(conn, rawRequest)
                            local method, url, httpVersion = string.match('GET / HTTP/1.1\r\n', '^([^%s]+)%s([^%s]+)%s([^\r]+)\r\n')
                            local req = {
                                app = this,
                                route = {},
                                raw = rawRequest,
                                url = url,
                                method = method,
                                httpVersion = httpVersion,
                                headers = {},
                                rawBody = '',
                                body = {},
                            }
                            local res = {
                                app = this,
                                sendRaw = function(this,rawRes)
                                    conn:send(rawRes)
                                end,
                                _headers = express.defaultHeaders,
                                statusCode = express.defaultStatusCode,
                                statusText = express.statusCodes[express.defaultStatusCode],
                                httpVersion = express.defaultHttpVersion
                            }
                            
                            -- Call middleware callbacks 
                            local middlewareCallbacksMaster = {} -- all middlewares that need to be called
                            for i = 1, #this.middlewares do
                                local middleware = this.middlewares[i]
                                local route = middleware.route
                                local callback = middleware.callback
                                
                                if string.sub(req.url,1,string.len(route)) == route then -- if url matches route pattern
                                    middlewareCallbacksMaster[#middlewareCallbacksMaster+1] = callback
                                end
                            end
                            local i = 1
                            local function _next()
                                if i > #middlewareCallbacksMaster then
                                    return
                                end
                                local middlewareCallback = middlewareCallbacksMaster[i]
                                i = i+1
                                middlewareCallback(req,res,_next)
                            end
                            _next()

                            -- Call route callbacks
                            local methodsToCheck = {'ALL',req.method}
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
                end,
                _addRoute = function(this, method, route, callback) -- internal function to add routes to the express instance
                    if not this.routes[method] then
                        this.routes[method] = {}
                        this.routes[method][route] = {} 
                    elseif not this.routes[method][route] then
                        this.routes[method][route] = {}
                    end
                    table.insert(this.routes[method][route],callback) --callback(req,res)
                end,
                use = function(this, route, callback) -- to add a middleware
                    if callback == nil then
                        callback = route
                        route = '/'
                    end
                    this.middlewares[#this.middlewares+1] = {["callback"]=callback, ["route"]=route} --callback(req, res, next) 
                end,
            }
            setmetatable(expressInstance,express.instanceMetaTable)
            return expressInstance
        end 
    })

    return express
end
