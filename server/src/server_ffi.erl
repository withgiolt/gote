-module(server_ffi).
-export([otp_release/0, pid_string/1, clock/0, timestamp/0, shell/1]).

otp_release() ->
    list_to_binary(erlang:system_info(otp_release)).

pid_string(Pid) ->
    list_to_binary(pid_to_list(Pid)).

%% HH:MM:SS of the server's wall clock, UTC.
clock() ->
    {_, {H, M, S}} = calendar:universal_time(),
    list_to_binary(io_lib:format("~2..0B:~2..0B:~2..0B UTC", [H, M, S])).

%% Only used by `main/0` on the BEAM, never on afterglow (no OS access there).
shell(Command) ->
    unicode:characters_to_binary(os:cmd(binary_to_list(Command))).

%% RFC 3339 time in UTC, for the prerendered page.
timestamp() ->
    list_to_binary(calendar:system_time_to_rfc3339(erlang:system_time(second), [{offset, "Z"}])).
