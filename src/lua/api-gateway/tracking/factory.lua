-- This factory creates the tracking object to be instatiated when the API Gateway starts
--
--  Usage:
--      init_worker_by_lua '
--          ngx.apiGateway = ngx.apiGateway or {}
--          ngx.apiGateway.tracking = require "api-gateway.validation.tracking"
--      ';
--
-- User: ddascal
-- Date: 10/03/15
-- Time: 19:56
--

local RequestTrackingManager = require "api-gateway.tracking.RequestTrackingManager"
local BlockingRulesValidator = require "api-gateway.tracking.validator.blockingRulesValidator"
local DelayingRulesValidator = require "api-gateway.tracking.validator.delayingRulesValidator"
local TrackingRulesLogger    = require "api-gateway.tracking.log.trackingRulesLogger"
local cjson = require "cjson"

--- Handler for REST API:
--   POST /tracking
local function _API_POST_Handler()
    local trackingManager = ngx.apiGateway.tracking.manager
    ngx.req.read_body()
    if ( ngx.req.get_method() == "POST" ) then
       local json_string = ngx.req.get_body_data()
       local success, err, forcible = trackingManager:addRule(json_string)
       if ( success ) then
          ngx.say('{"result":"success"}')
          return ngx.OK
       end
       ngx.log(ngx.WARN, "Error saving a new Rule. err=" .. tostring(err), ", forcible=" .. tostring(forcible))
       return ngx.HTTP_BAD_REQUEST
    end
end

--- Handler for REST API:
--    GET /tracking/{rule_type}
--
local function _API_GET_Handler(rule_type)
    local trackingManager = ngx.apiGateway.tracking.manager
    if ( ngx.req.get_method() == "GET" ) then
        local rules = trackingManager:getRulesForType(rule_type )
        ngx.say( cjson.encode(rules) )
        return ngx.OK
    end
    ngx.status = ngx.HTTP_BAD_REQUEST
end

--- Validates the request to see if there's any Blocking rule matching. If yes, it blocks the request
--
local function _validateServicePlan()
    local blockingRulesValidator = BlockingRulesValidator:new()
    local result, status = blockingRulesValidator:validateRequest()
    if(status == false) then
        return result
    end
    local delayingRulesValidator = DelayingRulesValidator:new()
    return delayingRulesValidator:validateRequestForDelaying()
end

--- Track the rules that are active, sending an async message to a queue with the usage
-- This method should be called from the log phase ( log_by_lua )
--
local function _trackRequest()
   local trackingRulesLogger = TrackingRulesLogger:new()
    return trackingRulesLogger:log()
end

return {
    manager = RequestTrackingManager:new(),
    validateServicePlan = _validateServicePlan,
    track = _trackRequest,
    POST_HANDLER = _API_POST_Handler,
    GET_HANDLER = _API_GET_Handler
}