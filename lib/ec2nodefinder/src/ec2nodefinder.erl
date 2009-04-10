%% @doc ec2-describe-instances based nodefinder service.
%% @end

-module (ec2nodefinder).
-export ([ discover/0 ]).
-behaviour (application).
-export ([ start/0, start/2, stop/0, stop/1 ]).


%-=====================================================================-
%-                                Public                               -
%-=====================================================================-

%% @spec discover () -> { ok, [ { Node::node (), pong | pang | timeout } ] }
%% @doc Initiate a discovery request.  Discovery is synchronous; the
%% results are returned.
%% @end

discover () ->
  ec2nodefindersrv:discover ().

%-=====================================================================-
%-                        application callbacks                        -
%-=====================================================================-

%% @hidden

start () ->
    inets:start(),
    crypto:start(),
    application:start (ec2nodefinder).

%% @hidden

start (_Type, _Args) ->
  Group = case application:get_env (ec2nodefinder, group) of
    { ok, G } -> G;
    _ -> first_security_group ()
  end,
  { ok, PingTimeout } = application:get_env (ec2nodefinder, ping_timeout_sec),
  ID = get_p(access, "AMAZON_ACCESS_KEY_ID"),
  Secret = get_p(secret, "AMAZON_SECRET_ACCESS_KEY"),
  ec2nodefindersup:start_link (Group, 
                               1000 * PingTimeout,
                               ID,
                               Secret).

%% @hidden

stop () -> 
  application:stop (ec2nodefinder).

%% @hidden

stop (_State) ->
  ok.

%-=====================================================================-
%-                               Private                               -
%-=====================================================================-

%% @private
get_p(Atom, Env)->
    case application:get_env(?MODULE,Atom) of
     {ok, Value} ->
         Value;
     undefined ->
         case os:getenv(Env) of
     	false ->
     	    error;
     	Value ->
     	    Value
         end
    end.
    
first_security_group () ->
  Url = "http://169.254.169.254/2007-08-29/meta-data/security-groups",
  case http:request (Url) of
    { ok, { { _HttpVersion, 200, _Reason }, _Headers, Body } } ->
      string:substr (Body, 1, string:cspan (Body, "\n"));
    BadResult ->
      erlang:error ({ http_request_failed, Url, BadResult })
  end.