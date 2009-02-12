%% @hidden

-module (ec2nodefindersup).
-behaviour (supervisor).

-export ([ start_link/4, init/1 ]).

%-=====================================================================-
%-                                Public                               -
%-=====================================================================-

start_link (Group, PingTimeout, Access, Secret) ->
  supervisor:start_link 
    (?MODULE, 
     [ Group, PingTimeout, Access, Secret ]).

init ([ Group, PingTimeout, Access, Secret ]) ->
  { ok,
    { { one_for_one, 3, 10 },
      [ { ec2nodefindersrv,
          { ec2nodefindersrv, 
            start_link,
            [ Group, PingTimeout, Access, Secret ] },
          permanent,
          10000,
          worker,
          [ ec2nodefindersrv ]
        }
      ]
    }
  }.
