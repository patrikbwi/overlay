%% Copyright (c) 2013, Patrik Winroth <patrik@bwi.se>
%%
%% Permission to use, copy, modify, and/or distribute this software for any
%% purpose with or without fee is hereby granted, provided that the above
%% copyright notice and this permission notice appear in all copies.
%% 
%% THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
%% WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
%% MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
%% ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
%% WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
%% ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
%% OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
%%
%% @doc Module that contains functions for handling a pseudo path.
%% @end

-module(psp).

-export([ init/0
        , new/0
        , is_loop/1
        , add_me/1
        ]).

-opaque psp() :: <<_:2560>>.
-export_type([psp/0]).

%%%_* API ======================================================================
%% @doc Initializes a random 128 bit crypto key, a random string and a counter.
-spec init() -> ok.
init() ->
  init_ets(),
  reset_crypto(),
  ok.

%% @doc Generate a new PSP where add_me/1 gives the only non-random entry.
-spec new() -> psp().
new() ->
  PSP = crypto:rand_bytes(16*20),
  add_me(PSP).

%% @doc Checks if there is an entry in the PSP that is us, i.e. we are looping.
-spec is_loop(psp()) -> boolean().
is_loop(PSP) ->
  [loop || <<Encrypted:128>> <= PSP, is_me(<<Encrypted:128>>)] =/= [].

%% @doc Add an entry to the PSP for this node.
-spec add_me(psp()) -> psp().
add_me(PSP) ->
  <<PS:2432, _:128>> = PSP,
  Cnt = inc_cnt(),
  Str = get_key(str),
  Me = encrypt(<<Str/binary, Cnt:48>>),
  <<Me/binary, PS:2432>>.

%%%_* Internal =================================================================
table() ->
  psp.

is_me(Encrypted) ->
  CurrentCnt = get_key(cnt),
  <<Str:80>> = get_key(str),
  case catch decrypt(Encrypted) of
    <<Str:80, Cnt:48>> when Cnt < CurrentCnt ->
      true;
    _ ->
      false
  end.

encrypt(B) ->
  crypto:block_encrypt(aes_cbc128, get_key(key), get_key(iv), B).

decrypt(B) ->
  crypto:block_decrypt(aes_cbc128, get_key(key), get_key(iv), B).

init_ets() ->
  ets:new(table() , [ set, public, named_table
		    , {read_concurrency, true}
                    , {write_concurrency, true}
                    ]).

reset_crypto() ->
  IV = crypto:rand_bytes(16),  
  Key = crypto:rand_bytes(16),
  Str = crypto:rand_bytes(10),
  Cnt = crypto:rand_bytes(6),
  <<IntCnt:48>> = Cnt,
  ets:insert(table(), [ {iv, IV}, {key, Key}
                      , {str, Str}, {cnt, IntCnt}]).

inc_cnt() ->
  case ets:update_counter(table(), cnt, {2, 1, 281474976710655, 0}) of
    0 = N ->
      reset_crypto(),
      N;
    N ->
      N
  end.

get_key(Key) ->
  [{_, Val}] = ets:lookup(table(), Key),
  Val.

%%%_* Emacs ====================================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
