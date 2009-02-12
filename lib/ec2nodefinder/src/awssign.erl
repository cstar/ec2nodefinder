-module(awssign).
-author('eric@ohmforce.com').
-include_lib("xmerl/include/xmerl.hrl").
-export([sign_and_send/5, describe_instances/5]).

sign_and_send(Params, Host,APIVersion, AccessKey, SecretKey)->
    SortedParams = sort([{"Timestamp", create_timestamp()},
                        {"SignatureVersion", "2"},
                        {"Version", APIVersion},
                        {"AWSAccessKeyId", AccessKey}, 
                        {"SignatureMethod", "HmacSHA1"}
                        |Params]),
    EncodedParams = lists:foldl(
        fun({K,V}, Acc)->
            [url_encode(K) ++ "=" ++ url_encode(V)| Acc]
        end,[], SortedParams),
    QueryString = string:join(EncodedParams, "&"),
    ToSign = "GET\n" ++ Host ++ "\n/\n" ++ QueryString,
    Signature = url_encode(
        binary_to_list(
            base64:encode(crypto:sha_mac(SecretKey, ToSign)))
        ),
    URL = "http://"++ Host ++ "/?" ++ QueryString ++ "&Signature=" ++ Signature,
    case http:request(URL) of
        {ok, {{_Version, 200, _ReasonPhrase}, _Headers, Body}} -> {ok, Body};
        {ok, {{_Version, Code, ReasonPhrase}, _Headers, _Body}} -> {error, {Code, ReasonPhrase} }
    end.

% lifted from http://code.google.com/p/erlawys/source/browse/trunk/src/aws_util.erl
create_timestamp() -> create_timestamp(calendar:now_to_universal_time(now())).
create_timestamp({{Y, M, D}, {H, Mn, S}}) ->
	to_str(Y) ++ "-" ++ to_str(M) ++ "-" ++ to_str(D) ++ "T" ++
	to_str(H) ++ ":" ++ to_str(Mn)++ ":" ++ to_str(S) ++ "Z".
add_zeros(L) -> if length(L) == 1 -> [$0|L]; true -> L end.
to_str(L) -> add_zeros(integer_to_list(L)).

    
sort(Params)->
    lists:sort(fun({A, _}, {X, _}) -> A > X end, Params).
    
describe_instances(SecurityGroup, Host,APIVersion, AccessKey, SecretKey)->
    Params =[ {"Action", "DescribeInstances"}],
    Res = sign_and_send(Params, Host, APIVersion, AccessKey, SecretKey),
    case Res of
        {ok, XML} ->
            {R,_} = xmerl_scan:string(XML),
            [ V#xmlText.value
                || V<- xmerl_xpath:string("/DescribeInstancesResponse/reservationSet/item[ groupSet/item/groupId = \""
                        ++ SecurityGroup ++ "\"]/instancesSet/item/privateDnsName/text()", R)];
        {error, E} ->
            erlang:error ({ describe_instances_failed, E }),
            []
    end.

% lifted from the ever precious yaws_utils.erl    
integer_to_hex(I) ->
    case catch erlang:integer_to_list(I, 16) of
        {'EXIT', _} ->
            old_integer_to_hex(I);
        Int ->
            Int
    end.

old_integer_to_hex(I) when I<10 ->
    integer_to_list(I);
old_integer_to_hex(I) when I<16 ->
    [I-10+$A];
old_integer_to_hex(I) when I>=16 ->
    N = trunc(I/16),
    old_integer_to_hex(N) ++ old_integer_to_hex(I rem 16).
url_encode([H|T]) ->
    if
        H >= $a, $z >= H ->
            [H|url_encode(T)];
        H >= $A, $Z >= H ->
            [H|url_encode(T)];
        H >= $0, $9 >= H ->
            [H|url_encode(T)];
        H == $_; H == $.; H == $-; H == $/ -> % FIXME: more..
            [H|url_encode(T)];
        true ->
            case integer_to_hex(H) of
                [X, Y] ->
                    [$%, X, Y | url_encode(T)];
                [X] ->
                    [$%, $0, X | url_encode(T)]
            end
     end;

url_encode([]) ->
    [].