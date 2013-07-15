_ = require "lodash"
async = require "async"

{ FakeAppTest } = require "../../../apiaxle_base"
{ Stats }   = require "../../../../app/model/redis/stats"

class exports.ArbStatsTest extends FakeAppTest
  @empty_db_on_setup = true

  "setup model": ( done ) ->
    @model = @app.model "arbstats"

    done()

  "test #roundedTimestamp": ( done ) ->
    @equal @model.roundedTimestamp( 60, 1000 ), 960
    @equal @model.roundedTimestamp( 60, 1021 ), 1020

    @equal @model.roundedTimestamp( 60, 120 ), 120
    @equal @model.roundedTimestamp( 1, 60 ), 60

    done 4

  "test a simple counter increment": ( done ) ->
    clock = @getClock 1357002210000 # Tue, 01 Jan 2013 01:03:30 GMT
    multi = @model.multi()

    # pretty print array of timestamps (used for debugging so that we
    # can see human readable dates too)
    valuesToIso = ( values ) ->
      _.map values, ( ts ) ->
        {}=
          ts: ts
          human: ( new Date( ts * 1000 ) ).toISOString()

    all = []
    all.push ( cb ) =>
      # 1356998400 => Tue, 01 Jan 2013 00:00:00 GMT
      # 1357002210 => Tue, 01 Jan 2013 01:03:30 GMT
      vals = @model.getKeyValueTimestamps( "second" )
      @deepEqual valuesToIso( vals ), valuesToIso( [ 1356998400, 1357002210 ] )

      # 1356998400 => Tue, 01 Jan 2013 00:00:00 GMT
      # 1357002180 => Tue, 01 Jan 2013 01:03:00 GMT
      vals = @model.getKeyValueTimestamps( "minute" )
      @deepEqual valuesToIso( vals ), valuesToIso( [ 1356998400, 1357002180 ] )

      # 1356566400 => Thu, 27 Dec 2012 00:00:00 GMT
      # 1357002000 => Tue, 01 Jan 2013 01:00:00 GMT
      vals = @model.getKeyValueTimestamps( "hour" )
      @deepEqual valuesToIso( vals ), valuesToIso( [ 1356566400, 1357002000 ] )

      cb()

    # 3 seconds later
    all.push ( cb ) =>
      clock.addSeconds 3
      # now we're at 1357002213 => Tue, 01 Jan 2013 01:03:33 GMT

      # 1356998400 => Tue, 01 Jan 2013 00:00:00 GMT
      # 1357002213 => Tue, 01 Jan 2013 01:03:33 GMT
      vals = @model.getKeyValueTimestamps( "second" )
      @deepEqual valuesToIso( vals ), valuesToIso( [ 1356998400, 1357002213 ] )

      # doesn't change this round
      # 1356998400 => Tue, 01 Jan 2013 00:00:00 GMT
      # 1357002180 => Tue, 01 Jan 2013 01:03:00 GMT
      vals = @model.getKeyValueTimestamps( "minute" )
      @deepEqual valuesToIso( vals ), valuesToIso( [ 1356998400, 1357002180 ] )

      # doesn't change this round
      # 1356566400 => Thu, 27 Dec 2012 00:00:00 GMT
      # 1357002000 => Tue, 01 Jan 2013 01:00:00 GMT
      vals = @model.getKeyValueTimestamps( "hour" )
      @deepEqual valuesToIso( vals ), valuesToIso( [ 1356566400, 1357002000 ] )

      cb()

    # 3 minutes later
    all.push ( cb ) =>
      clock.addMinutes 3
      # now we're at 1357002393 => Tue, 01 Jan 2013 01:06:33 GMT

      # 1356998400 => Tue, 01 Jan 2013 00:00:00 GMT
      # 1357002213 => Tue, 01 Jan 2013 01:06:33 GMT
      vals = @model.getKeyValueTimestamps( "second" )
      @deepEqual valuesToIso( vals ), valuesToIso( [ 1356998400, 1357002393 ] )

      # 1356998400 => Tue, 01 Jan 2013 00:00:00 GMT
      # 1357002360 => Tue, 01 Jan 2013 01:06:00 GMT
      vals = @model.getKeyValueTimestamps( "minute" )
      @deepEqual valuesToIso( vals ), valuesToIso( [ 1356998400, 1357002360 ] )

      # doesn't change this round
      # 1356566400 => Thu, 27 Dec 2012 00:00:00 GMT
      # 1357002000 => Tue, 01 Jan 2013 01:00:00 GMT
      vals = @model.getKeyValueTimestamps( "hour" )
      @deepEqual valuesToIso( vals ), valuesToIso( [ 1356566400, 1357002000 ] )

      cb()

    # 3 hours later
    all.push ( cb ) =>
      clock.addHours 3
      # now we're at 1357013193 => Tue, 01 Jan 2013 04:06:33 GMT

      # 1357012800 => Tue, 01 Jan 2013 04:00:00 GMT
      # 1357013193 => Tue, 01 Jan 2013 04:06:33 GMT
      vals = @model.getKeyValueTimestamps( "second" )
      @deepEqual valuesToIso( vals ), valuesToIso( [ 1357012800, 1357013193 ] )

      # 1356998400 => Tue, 01 Jan 2013 00:00:00 GMT
      # 1357002360 => Tue, 01 Jan 2013 04:06:00 GMT
      vals = @model.getKeyValueTimestamps( "minute" )
      @deepEqual valuesToIso( vals ), valuesToIso( [ 1356998400, 1357013160 ] )

      # 1356566400 => Thu, 27 Dec 2012 00:00:00 GMT
      # 1357012800 => Tue, 01 Jan 2013 04:00:00 GMT
      vals = @model.getKeyValueTimestamps( "hour" )
      @deepEqual valuesToIso( vals ), valuesToIso( [ 1356566400, 1357012800 ] )

      cb()

    # 3 days later
    all.push ( cb ) =>
      clock.addDays 3
      # now we're at 1357272393 => Fri, 04 Jan 2013 04:06:33 GMT

      # 1357272000 => Fri, 04 Jan 2013 04:00:00 GMT
      # 1357272393 => Fri, 04 Jan 2013 04:06:33 GMT
      vals = @model.getKeyValueTimestamps( "second" )
      @deepEqual valuesToIso( vals ), valuesToIso( [ 1357272000, 1357272393 ] )

      # 1357257600 => Fri, 04 Jan 2013 00:00:00 GMT
      # 1357272360 => Fri, 04 Jan 2013 04:06:00 GMT
      vals = @model.getKeyValueTimestamps( "minute" )
      @deepEqual valuesToIso( vals ), valuesToIso( [ 1357257600, 1357272360 ] )

      # 1357171200 => Thu, 03 Jan 2013 00:00:00 GMT
      # 1357272000 => Fri, 04 Jan 2013 04:00:00 GMT
      vals = @model.getKeyValueTimestamps( "hour" )
      @deepEqual valuesToIso( vals ), valuesToIso( [ 1357171200, 1357272000 ] )

      cb()

    async.series all, ( err ) =>
      @ok not err

      done 21