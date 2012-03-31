url = require "url"
crypto = require "crypto"
request = require "request"

{ TimeoutError } = require "../../lib/error"
{ ApiaxleController } = require "./controller"

class CatchAll extends ApiaxleController
  @cachable: false

  path: ( ) -> "*"

  middleware: -> [ @simpleBodyParser, @subdomain, @api, @apiKey ]

  _cacheHash: ( url ) ->
    md5 = crypto.createHash "md5"
    md5.update @app.constructor.env
    md5.update url
    md5.digest "hex"

  _cacheTtl: ( req, cb ) ->
    # no caching
    if not @.constructor.cachable
      return cb null, false, 0

    mustRevalidate = false

    # cache-control might want us to do something. We only care about
    # a few of the pragmas
    if cacheControl = @_parseCacheControl req

      # we might have to revalidate if the client has asked us to
      mustRevalidate = ( not not cacheControl[ "proxy-revalidate" ] )

      # don't cache anything
      if cacheControl[ "no-cache" ]
        return cb null, mustRevalidate, 0

      # explicit ttl
      if ttl = cacheControl[ "s-maxage" ]
        return cb null, mustRevalidate, ttl

    # return the global cache
    return cb null, mustRevalidate, parseInt req.api.globalCache

  # returns an object which looks like this (with all fields being
  # optional):
  #
  # {
  #   "s-maxage" : <seconds>
  #   "proxy-revalidate" : true|false
  #   "no-cache" : true|false
  # }
  _parseCacheControl: ( req ) ->
    return {} unless req.headers["cache-control"]

    res = {}
    header = req.headers["cache-control"].replace new RegExp( " ", "g" ), ""

    for directive in header.split ","
      [ key, value ] = directive.split "="
      value or= true

      res[ key ] = value

    return res

  # TODO: We need to fix the response code (it should match the
  # original one).
  _fetch: ( req, options, outerCb ) ->
    # check for caching, pass straight through if we don't want a
    # cache (the 0 is a string because it comes straight from redis).
    @_cacheTtl req, ( err, mustRevalidate, cacheTtl ) =>
      if cacheTtl is 0 or mustRevalidate
        return @_httpRequest options, req.apiKey.key, outerCb

      cache = @app.model "cache"
      key = @_cacheHash options.url

      cache.get key, ( err, body ) =>
        return outerCb err if err

        # TODO: does anything need setting in terms of the
        # apiresponse? Should we have cached the headers?
        if body
          @app.logger.debug "Cache hit: #{options.url}"
          return @app.model( "counters" ).apiHit req.apiKey.key, 200, ( err, res ) ->
            outerCb err, { }, body

        @app.logger.debug "Cache miss: #{options.url}"

        # means we've a cache miss and so need to make a real request
        @_httpRequest options, req.apiKey.key, ( err, apiRes, body ) =>
          return outerCb err if err

          cache.add key, cacheTtl, body, ( err ) =>
            return outerCb err, apiRes, body

  _httpRequest: ( options, api_key, cb) ->
    counterModel = @app.model "counters"

    request[ @constructor.verb ] options, ( err, apiRes, body ) ->
      if err
        # if we timeout then throw an error
        if err.code is "ETIMEDOUT"
          counterModel.apiHit api_key, "timeout", ( counterErr, res ) ->
            return cb counterErr if counterErr
            return cb new TimeoutError( "API endpoint timed out." )
        else
          error = new Error "'#{ options.url }' yielded '#{ err.message }'"
          return cb error, null
      else
        # response with the same code as the endpoint
        counterModel.apiHit api_key, apiRes.statusCode, ( err, res ) ->
          return cb err, apiRes, body

  execute: ( req, res, next ) ->
    { pathname, query } = url.parse req.url, true

    # we should make this optional
    if query.apiaxle_key?
      delete query.apiaxle_key
    else
      delete query.api_key

    model = @app.model "apiLimits"

    { qps, qpd, key } = req.apiKey

    model.apiHit key, qps, qpd, ( err, [ newQps, newQpd ] ) =>
      if err
        counterModel = @app.model "counters"

        # collect the type of error (QpsExceededError or
        # QpdExceededError at the moment)
        type = err.constructor.name

        return counterModel.apiHit req.apiKey.key, type, ( counterErr, res ) ->
          return next counterErr if counterErr
          return next err

      # copy the headers
      headers = req.headers
      delete headers.host

      endpointUrl = "http://#{ req.api.endPoint }/#{ pathname }"
      if query
        endpointUrl += "?"
        newStrings = ( "#{ key }=#{ value }" for key, value of query )
        endpointUrl += newStrings.join( "&" )

      options =
        url: endpointUrl
        followRedirects: true
        maxRedirects: req.api.endPointMaxRedirects
        timeout: req.api.endPointTimeout * 1000
        headers: headers

      options.body = req.body

      @_fetch req, options, ( err, apiRes, body ) =>
        return next err if err

        # copy headers from the endpoint
        for header, value of apiRes.headers
          res.header header, value

        # let the user know what they've got left
        res.header "X-ApiaxleProxy-Qps-Left", newQps
        res.header "X-ApiaxleProxy-Qpd-Left", newQpd

        res.send body, apiRes.statusCode

class exports.GetCatchall extends CatchAll
  @cachable: true

  @verb: "get"

class exports.PostCatchall extends CatchAll
  @verb: "post"

class exports.PutCatchall extends CatchAll
  @verb: "put"

class exports.DeleteCatchall extends CatchAll
  @verb: "delete"